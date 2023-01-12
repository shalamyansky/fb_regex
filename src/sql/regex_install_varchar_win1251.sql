-- Installation
-- (for Windows only)
--
-- 1. Copy fb_regex.dll to %firebird%\plugins\udr
--      where %firebird% is Firebird 4(3) server root directory.
--
--    Make sure library module matches the Firebird bitness.
--
-- 2. You can change all or some varchar() parameters to any length char, varchar
--    or blob sub_type text with character set UTF8 or WIN1251.
--
-- 3. Connect to target database and execute this script.

set term ^;

create or alter package regex
as begin

procedure matches(
    text    varchar(32765) character set WIN1251
  , pattern varchar(32765) character set WIN1251
)returns(
    number  integer
  , groups  varchar(32765) character set WIN1251
);

procedure groups(
    groups varchar(32765) character set WIN1251
)returns(
    number integer
  , origin integer
  , finish integer
);

procedure find(
    text    varchar(32765) character set WIN1251
  , pattern varchar(32765) character set WIN1251
  , amount  integer
  , pass    integer
)returns(
    number  integer
  , match   varchar(32765) character set WIN1251
);

function find_first(
    text    varchar(32765) character set WIN1251
  , pattern varchar(32765) character set WIN1251
  , pass    integer
)returns    varchar(32765) character set WIN1251;

function replace(
    text        varchar(32765) character set WIN1251
  , pattern     varchar(32765) character set WIN1251
  , replacement varchar(32765) character set WIN1251
  , amount      integer
  , pass        integer
)returns        varchar(32765) character set WIN1251;

procedure split_words(
    text   varchar(32765) character set WIN1251
)returns(
    number integer
  , word   varchar(32765) character set WIN1251
);

procedure split(
    text      varchar(32765) character set WIN1251
  , separator varchar(32765) character set WIN1251
)returns(
    number    integer
  , part      varchar(32765) character set WIN1251
);

end^

recreate package body regex
as
begin

procedure matches(
    text    varchar(32765) character set WIN1251
  , pattern varchar(32765) character set WIN1251
)returns(
    number  integer
  , groups  varchar(32765) character set WIN1251
)external name
    'fb_regex!matches'
engine
    udr
;

procedure groups(
    groups varchar(32765) character set WIN1251
)returns(
    number integer
  , origin integer
  , finish integer
)external name
    'fb_regex!groups'
engine
    udr
;

procedure find(
    text    varchar(32765) character set WIN1251
  , pattern varchar(32765) character set WIN1251
  , amount  integer
  , pass    integer
)returns(
    number  integer
  , match   varchar(32765) character set WIN1251
)external name
    'fb_regex!find'
engine
    udr
;

function find_first(
    text    varchar(32765) character set WIN1251
  , pattern varchar(32765) character set WIN1251
  , pass    integer
)returns    varchar(32765) character set WIN1251
external name
    'fb_regex!find_first'
engine
    udr
;

function replace(
    text        varchar(32765) character set WIN1251
  , pattern     varchar(32765) character set WIN1251
  , replacement varchar(32765) character set WIN1251
  , amount      integer
  , pass        integer
)returns        varchar(32765) character set WIN1251
external name
    'fb_regex!replace'
engine
    udr
;

procedure split_words(
    text   varchar(32765) character set WIN1251
)returns(
    number integer
  , word   varchar(32765) character set WIN1251
)external name
    'fb_regex!split_words'
engine
    udr
;

procedure split(
    text      varchar(32765) character set WIN1251
  , separator varchar(32765) character set WIN1251
)returns(
    number    integer
  , part      varchar(32765) character set WIN1251
)external name
    'fb_regex!split'
engine
    udr
;

end^

set term ;^
