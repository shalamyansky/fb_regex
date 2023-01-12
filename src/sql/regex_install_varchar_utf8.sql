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
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
)returns(
    number  integer
  , groups  varchar(8191) character set UTF8
);

procedure groups(
    groups varchar(8191) character set UTF8
)returns(
    number integer
  , origin integer
  , finish integer
);

procedure find(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
  , amount  integer
  , pass    integer
)returns(
    number  integer
  , match   varchar(8191) character set UTF8
);

function find_first(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
  , pass    integer
)returns    varchar(8191) character set UTF8;

function replace(
    text        varchar(8191) character set UTF8
  , pattern     varchar(8191) character set UTF8
  , replacement varchar(8191) character set UTF8
  , amount      integer
  , pass        integer
)returns        varchar(8191) character set UTF8;

procedure split_words(
    text   varchar(8191) character set UTF8
)returns(
    number integer
  , word   varchar(8191) character set UTF8
);

procedure split(
    text      varchar(8191) character set UTF8
  , separator varchar(8191) character set UTF8
)returns(
    number    integer
  , part      varchar(8191) character set UTF8
);

end^

recreate package body regex
as
begin

procedure matches(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
)returns(
    number  integer
  , groups  varchar(8191) character set UTF8
)external name
    'fb_regex!matches'
engine
    udr
;

procedure groups(
    groups varchar(8191) character set UTF8
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
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
  , amount  integer
  , pass    integer
)returns(
    number  integer
  , match   varchar(8191) character set UTF8
)external name
    'fb_regex!find'
engine
    udr
;

function find_first(
    text    varchar(8191) character set UTF8
  , pattern varchar(8191) character set UTF8
  , pass    integer
)returns    varchar(8191) character set UTF8
external name
    'fb_regex!find_first'
engine
    udr
;

function replace(
    text        varchar(8191) character set UTF8
  , pattern     varchar(8191) character set UTF8
  , replacement varchar(8191) character set UTF8
  , amount      integer
  , pass        integer
)returns        varchar(8191) character set UTF8
external name
    'fb_regex!replace'
engine
    udr
;

procedure split_words(
    text   varchar(8191) character set UTF8
)returns(
    number integer
  , word   varchar(8191) character set UTF8
)external name
    'fb_regex!split_words'
engine
    udr
;

procedure split(
    text      varchar(8191) character set UTF8
  , separator varchar(8191) character set UTF8
)returns(
    number    integer
  , part      varchar(8191) character set UTF8
)external name
    'fb_regex!split'
engine
    udr
;

end^

set term ;^
