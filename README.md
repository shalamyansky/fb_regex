# fb_regex
This is an extension library for DBMS Firebird 3.0/4.0 to support regular expressions in SQL.

## Basis

Library is implemented as а User Defined Routines (UDR) module of Firebird plugins architecture.
Other side the DLL is compiled by Delphi XE3 and uses the RegularExpression unit, which itself wraps PCRE 7.9. Thus to understand possibilities fb_regex regular expressions see [PCRE documentation](http://pcre.org/).


## Routines

Routines are joined into package named **regex**. Pseudotype **string** mark any of string type **char**, **varchar** of any length or **blob sub_type text**. All the routines can accept and return any string type.

### matches

    procedure matches(

        text    string    -- text to explore

      , pattern string    -- regular expression pattern to seek

    )returns(

        number  integer   -- order number of found match started from 1

      , groups  string    -- string containing groups boundaries in found match

    );

This is selective procedure, each result set row contains data of one match.

Output string **groups** contains groups boundaries of the match as semicolumn delimited pairs **start:finish** where start and finish are numeric position of symbol in text started from 1.    
    

## Examples


## Limitations


## Installation

 