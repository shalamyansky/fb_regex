# fb_regex
This is an extension library for RDBMS Firebird 3.0/4.0 to support regular expressions in SQL.

## Basis

Library is implemented as а User Defined Routines (UDR) module of Firebird plugins architecture.
Other side the DLL is compiled by Delphi XE3 and uses the RegularExpression unit, which itself wraps PCRE 7.9. Thus to understand possibilities fb_regex regular expressions see [PCRE documentation](http://pcre.org/).


## Routines

Routines are assembled into package ***regex***. Pseudotype ***string*** marks any of string type ***char***, ***varchar*** of any length or ***blob sub_type text***. All the routines can accept and return any string type.

## procedure *matches*

    procedure matches(
        text    string    -- text to explore
      , pattern string    -- regular expression pattern to seek
    )returns(
        number  integer   -- order number of found match started from 1
      , groups  string    -- string containing groups boundaries of found match
    );

This is selective procedure, each result set row contains data of one match.

Output string ***groups*** contains groups boundaries of the match as semicolumn delimited pairs ***start:finish*** where ***start*** and ***finish*** are numeric positions in ***text*** started from 1.    
    

## procedure *groups*

    procedure groups(
        groups  string   -- string containing groups boundaries of match
    )returns(
        number  integer  -- order number of group. 0 group is the whole match
      , origin  integer  -- start position of the group in text
      , finish  integer  -- first position after the group in text
    );

This is selective procedure, each row is one group. The procedure just parses string ***groups*** returned by procedure ***matches*** onto separate rows.

***matches and groups*** procedures are designed to work in conjunction. You can control a result by standard SQL features. See а sample:


    text : 'To be or not to be? Not to ask!'

    task : find the second word follows 'not to'.  

    solution:
      select
            g.origin
          , g.finish
          , substring( :text from g.origin for g.finish - g.origin ) as word
        from
            regex.matches( :text, '(?i)not\s+to\s+(\w+)' ) m
          left join regex.groups( m.groups ) g
            on ( g.number = 1 )
        where
          m.number = 2

     result:    
        ORIGIN       FINISH WORD
        ====== ============ =====
            28           31 ask

## procedure *find*

    procedure find(
        text    string    -- text to explore
      , pattern string    -- regular expression pattern to seek
      , amount  integer   -- maximum amount of rows to return
      , pass    integer   -- amount to skip first rows
    )returns(
        number  integer   -- order number of found match started from 1
      , match   string    -- match string value
    );

***find*** is a more simple selective prоcedure. It works like ***matches*** but returns match string value instead of match boundaries and does not support groups to extract. Sample:

    text : 'To be or not to be? Not to ask!'

    task : find all 'to' with followed words. Skip the first match.  

    solution:
        select
            *
          from
            regex.find( :text, '(?i)to\s+(\w+)', null, 1 )

     result:    
        NUMBER MATCH
        ====== ======
             1 to be
             2 to ask

## function *find_first*

    function find_first(
        text    string    -- text to explore
      , pattern string    -- regular expression pattern to seek
      , pass    integer   -- amount to skip first rows
    )returns    string;   -- first match string value

***find_first*** is a function that works like ***find*** but returns a single scalar result.

    text : 'To be or not to be? Not to ask!'

    task : get first 'not to' with first followed word.  

    solution:
        select
            regex.find_first( :text, '(?i)to\s+(\w+)', null )
          from
            rdb$database

     result:    
        FIND_FIRST
        ==========
        not to be

## function *replace*

    function replace(
        text        string    -- text to update
      , pattern     string    -- regular expression pattern to seek
      , replacement string    -- value to replace with
      , amount      integer   -- amount of matches to replace 
      , pass        integer   -- amount to skip first matches
    )returns        string;   -- updated text

Function ***replace*** seeks matches in ***text*** and replaces its with ***replacement***. Supports **$n** syntax in ***replacement***, where **n** is a ***pattern*** group number.  

    text : 'x = position (text,substring); y = position(a,b);'

    task : find all the calls of 'position' and exchange its parameters. Format calls as position( a, b ).  

    solution:
        select
            regex.replace( :text, 'position\s*\(\s*(\w+)\s*,\s*(\w+)\s*\)', 'position( $2, $1 )', null,  null )
          from
            rdb$database

     result:    
        REPLACE
        ==========
        x = position( substring, text ); y = position( b, a );
_

    text : 'x = position (text,substring); y = position(a,b);'

    task : find all the calls of 'position' and exchange its parameters. Do not any reformat.  

    solution:
        select
            regex.replace( :text, '(position\s*\(\s*)(\w+)(\s*,\s*)(\w+)(\s*\))', '$1$4$3$2$5', null,  null )
          from
            rdb$database

     result:    
        REPLACE
        ==========
        x = position (substring,text); y = position(b,a);

## procedure *split*

    procedure split(
        text      string    -- text to explore
      , separator string    -- regular expression pattern to seek separators
    )returns(
        number    integer   -- part order number  
      , part      string    -- part between separators
    );

***split*** cuts ***text*** onto parts delimited by ***separator***. Since ***separator*** is not a simple string but regular exspression do not forget escape special symbols if any. 

    text : 'Hamlet. To be or not to be? Not to ask!'

    task : split text onto parts delimited by ".", "?" or "!".  

    solution:
        select
            *
          from
            regex.split( :text, '[.?!]' )

     result:    
          NUMBER SPLIT
        ======== ========================
               1 Hamlet
               2 To be or not to be
               3 Not to ask
               4 <null>

## procedure *split_words*

    procedure split_words(
        text      string    -- text to explore
    )returns(
        number    integer   -- word order number  
      , word      string    -- standalone word 
    );

***split_words*** picks up standalone words. It treats any digit, english (latin) or russian cyrillic letter as a word symbol. It is equavalent ***find*** **( .., '[0-9A-Za-zА-Яа-яЁё]+', , )** except a bit faster. 

    text : 'To be or not to be?'

    task : extract all the words.  

    solution:
        select
            *
          from
            regex.split_words( text )

     result:    
          NUMBER SPLIT_WORDS
        ======== ===================
               1 To
               2 be
               3 or
               4 not
               5 to
               6 be

## Limitations

Regular expression syntax defined by PCRE 7.9.

No limits for strings length and result set volume.

Supports all the string types - char(), varchar() and blob sub_type text of any allowed length for this types.

Supports 2 character sets: UTF8 (1-4 bytes/symbol) and WIN1251 (1-byte russian cyrillic charset for Windows). 


## Installation


0. Download a release package.

1. Copy fb_regex.dll to %firebird%\plugins\udr
   where %firebird% is Firebird 4(3) server root directory.
   Make sure library module matches the Firebird bitness.

2. Look at script in fb_regex_utf8.sql. You can change all or some varchar() parameters to any length char, varchar
   or blob sub_type text with character set UTF8 or WIN1251.

3. Connect to target database and execute the script.


## Using

You can use binaries as you see fit.

If you get code or part of code please keep my name and a link [here](https://github.com/shalamyansky/fb_regex).   
