%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: BSD-2-Clause
%%
%% Copyright (c) 2008,2009 Robert Virding. All rights reserved.
%% Copyright Ericsson AB 2009-2025. All Rights Reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions
%% are met:
%%
%% 1. Redistributions of source code must retain the above copyright
%% notice, this list of conditions and the following disclaimer.
%% 2. Redistributions in binary form must reproduce the above copyright
%% notice, this list of conditions and the following disclaimer in the
%% documentation and/or other materials provided with the distribution.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%% FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
%% COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
%% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
%% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
%% ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%% POSSIBILITY OF SUCH DAMAGE.
%%
%% %CopyrightEnd%
%% 

%%% A Lexical Analyser Generator for Erlang.
%%%
%%% Most of the algorithms used here are taken pretty much as
%%% described in the "Dragon Book" by Aho, Sethi and Ullman. Some
%%% completing details were taken from "Compiler Design in C" by
%%% Hollub.

-module(leex).
-moduledoc """
Lexical analyzer generator for Erlang

A regular expression based lexical analyzer generator for Erlang, similar to
`lex` or `flex`.

> #### Note {: .info }
>
> The `leex` module was considered experimental when it was introduced.

## Default Leex Options

The (host operating system) environment variable `ERL_COMPILER_OPTIONS` can be
used to give default Leex options. Its value must be a valid Erlang term. If the
value is a list, it is used as is. If it is not a list, it is put into a list.

The list is appended to any options given to `file/2`.

The list can be retrieved with `compile:env_compiler_options/0`.

## Input File Format

Erlang style comments starting with a `%` are allowed in scanner files. A
definition file has the following format:

```text
<Header>

Definitions.

<Macro Definitions>

Rules.

<Token Rules>

Erlang code.

<Erlang code>
```

The `Definitions.`, `Rules.`, and `Erlang code` headings are mandatory
and must start at the beginning of a source line. The `<Header>`,
`<Macro Definitions>`, and `<Erlang code>` sections are allowed to be
empty, but there must be at least one rule.

Macro definitions have the following format:

```text
NAME = VALUE
```

and there must be spaces around `=`. Macros can be used in the regular
expressions of rules by writing `{NAME}`.

> #### Note {: .info }
>
> When macros are expanded in expressions, the macro calls are replaced by the
> macro value without any form of quoting or enclosing in parentheses.

Rules have the following format:

```text
<Regexp> : <Erlang code>.
```

The `<Regexp>` must occur at the start of a line and not include any blanks; use
`\t` and `\s` to include TAB and SPACE characters in the regular expression. If
`<Regexp>` matches then the corresponding `<Erlang code>` is evaluated to generate a
token. With the Erlang code the following predefined variables are available:

- **`TokenChars`** - A list of the characters in the matched token.

- **`TokenLen`** - The number of characters in the matched token.

- **`TokenLine`** - The line number where the token occurred.

- **`TokenCol`** - The column number where the token occurred (column of the
  first character included in the token).

- **`TokenLoc`** - Token location. Expands to `{TokenLine,TokenCol}` (even when
  `error_location` is set to `line`).

The code must return:

- **`{token,Token}`** - Return `Token` to the caller.

- **`{end_token,Token}`** - Return `Token` and is last token in a tokens call.

- **`skip_token`** - Skip this token completely.

- **`{error,ErrString}`** - An error in the token, `ErrString` is a string
  describing the error.

It is also possible to push back characters into the input characters with the
following returns:

- `{token,Token,PushBackList}`
- `{end_token,Token,PushBackList}`
- `{skip_token,PushBackList}`

These have the same meanings as the normal returns but the characters in
`PushBackList` will be prepended to the input characters and scanned for the
next token. Note that pushing back a newline will mean the line numbering will
no longer be correct.

> #### Note {: .info }
>
> Pushing back characters gives you unexpected possibilities to cause the
> scanner to loop\!

The following example would match a simple Erlang integer or float and return a
token which could be sent to the Erlang parser:

```erlang
D = [0-9]

{D}+ :
  {token,{integer,TokenLine,list_to_integer(TokenChars)}}.

{D}+\.{D}+((E|e)(\+|\-)?{D}+)? :
  {token,{float,TokenLine,list_to_float(TokenChars)}}.
```

The Erlang code in the `Erlang code.` section is written into the output file
directly after the module declaration and predefined exports declaration, making
it possible to add extra exports, define imports, and other attributes, which are
visible in the whole file.

## Regular Expressions

The regular expressions allowed here is a subset of the set found in `egrep` and
in the AWK programming language, as defined in the book _The AWK Programming
Language_ by A. V. Aho, B. W. Kernighan, and P. J. Weinberger. They are composed of
the following characters:

- **`c`** - Matches the non-metacharacter c.

- **`\c`** - Matches the escape sequence or literal character c.

- **`.`** - Matches any character.

- **`^`** - Matches the beginning of a string.

- **`$`** - Matches the end of a string.

- **`[abc...]`** - Character class, which matches any of the characters
  `abc...`. Character ranges are specified by a pair of characters separated by
  a `-`.

- **`[^abc...]`** - Negated character class, which matches any character except
  `abc...`.

- **`r1 | r2`** - Alternation. It matches either `r1` or `r2`.

- **`r1r2`** - Concatenation. It matches `r1` and then `r2`.

- **`r+`** - Matches one or more `r`s.

- **`r*`** - Matches zero or more `r`s.

- **`r?`** - Matches zero or one `r`s.

- **`(r)`** - Grouping. It matches `r`.

The escape sequences allowed are the same as for Erlang strings:

- **`\b`** - Backspace.

- **`\f`** - Form feed.

- **`\n`** - Newline (line feed).

- **`\r`** - Carriage return.

- **`\t`** - Tab.

- **`\e`** - Escape.

- **`\v`** - Vertical tab.

- **`\s`** - Space.

- **`\d`** - Delete.

- **`\ddd`** - The octal value `ddd`.

- **`\xhh`** - The hexadecimal value `hh`.

- **`\x{h...}`** - The hexadecimal value `h...`.

- **`\c`** - Any other character literally, for example `\\` for backslash, `\"`
  for `"`.

The following examples define simplified versions of a few Erlang data types:

```text
Atoms [a-z][0-9a-zA-Z_]*

Variables [A-Z_][0-9a-zA-Z_]*

Floats (\+|-)?[0-9]+\.[0-9]+((E|e)(\+|-)?[0-9]+)?
```

> #### Note {: .info }
>
> Anchoring a regular expression with `^` and `$` is not implemented in the
> current version of `leex` and generates a parse error.
""".

-export([compile/3,file/1,file/2,format_error/1]).

-import(lists, [member/2,reverse/1,sort/1,keysort/2,
                map/2,foldl/3,foldr/3,foreach/2,flatmap/2]).
-import(ordsets, [is_element/2,add_element/2,union/2]).
-import(orddict, [store/3]).

-include("erl_compile.hrl").
%%-include_lib("stdlib/include/erl_compile.hrl").

-define(LEEXINC, "leexinc.hrl").        % Include file
-define(LEEXLIB, parsetools).           % Leex is in lib parsetools
%%-define(LEEXLIB, leex).               % Leex is in lib leex

-define(DEFS_HEAD, "Definitions.").
-define(RULE_HEAD, "Rules.").
-define(CODE_HEAD, "Erlang code.").

-record(leex, {xfile=[],        % Xrl file
               efile=[],        % Erl file
               ifile=[],        % Include file
               gfile=[],        % Graph file
               module,          % Module name
               opts=[],         % Options
               encoding=none,   % Encoding of Xrl file
               % posix=false,   % POSIX regular expressions
               errors=[],
               warnings=[]
              }).

-record(nfa_state, {no,edges=[],accept=noaccept}).
-record(dfa_state, {no,nfa=[],trans=[],accept=noaccept}).

%%%
%%% Functions that generated scanner exports,
%%% only used for documentation purposes
%%%
-export([string/1, string/2, token/2, token/3, tokens/2, tokens/3]).
-doc #{equiv => string(String, 1)}.
-doc(#{group => <<"Generated Scanner Exports">>}).
-spec string(String) -> StringRet when
      String :: string(),
      StringRet :: {ok, Tokens, EndLoc} | ErrorInfo,
      Tokens :: [Token],
      Token :: term(),
      ErrorInfo :: {error, error_info(), erl_anno:location()},
      EndLoc :: erl_anno:location().
string(_String) -> erlang:nif_error(undef).
-doc """
Scans `String` and returns either all the tokens in it or an `error` tuple.

`StartLoc` and `EndLoc` are either [`erl_anno:line()`](`t:erl_anno:line/0`)
or [`erl_anno:location()`](`t:erl_anno:location/0`), depending on the
`error_location` option.

> #### Note {: .info }
>
> It is an error if not all of the characters in `String` are consumed.
""".
-doc(#{group => <<"Generated Scanner Exports">>}).
-spec string(String, StartLoc) -> StringRet when
      String :: string(),
      StringRet :: {ok, Tokens, EndLoc} | ErrorInfo,
      Tokens :: [Token],
      Token :: term(),
      ErrorInfo :: {error, error_info(), erl_anno:location()},
      StartLoc :: erl_anno:location(),
      EndLoc :: erl_anno:location().
string(_String, _StartLoc) -> erlang:nif_error(undef).

-doc #{equiv => token(Cont, Chars, 1)}.
-doc(#{group => <<"Generated Scanner Exports">>}).
-spec token(Cont, Chars) ->
    {more, Cont1} | {done, TokenRet, RestChars} when
      Cont :: [] | Cont1,
      Cont1 :: tuple(),
      Chars :: string() | eof,
      RestChars :: string() | eof,
      TokenRet :: {ok, Token, EndLoc} |
                  {eof, EndLoc} |
                  ErrorInfo,
      ErrorInfo :: {error, error_info(), erl_anno:location()},
      Token :: term(),
      EndLoc :: erl_anno:location().
token(_Cont, _Chars) -> erlang:nif_error(undef).

-doc """
This is a re-entrant call to try and scan a single token from `Chars`.

If there are enough characters in `Chars` to either scan a token or
detect an error then this will be returned with
`{done,...}`. Otherwise `{cont,Cont}` will be returned where `Cont` is
used in the next call to `token()` with more characters to try an scan
the token. This is continued until a token has been scanned. `Cont` is
initially `[]`.

It is not designed to be called directly by an application, but is
used through the I/O system where it can typically be called in an
application by:

```erlang
io:request(InFile, {get_until,unicode,Prompt,Module,token,[Loc]})
  -> TokenRet
```
""".
-doc(#{group => <<"Generated Scanner Exports">>}).
-spec token(Cont, Chars, StartLoc) ->
    {more, Cont1} | {done, TokenRet, RestChars} when
      Cont :: [] | Cont1,
      Cont1 :: tuple(),
      Chars :: string() | eof,
      RestChars :: string() | eof,
      TokenRet :: {ok, Token, EndLoc} |
                  {eof, EndLoc} |
                  ErrorInfo,
      ErrorInfo :: {error, error_info(), erl_anno:location()},
      Token :: term(),
      StartLoc :: erl_anno:location(),
      EndLoc :: erl_anno:location().
token(_Cont, _Chars, _StartLoc) -> erlang:nif_error(undef).

-doc #{equiv => tokens(Cont, Chars, 1)}.
-doc(#{group => <<"Generated Scanner Exports">>}).
-spec tokens(Cont, Chars) ->
    {more, Cont1} | {done, TokensRet, RestChars} when
      Cont :: [] | Cont1,
      Cont1 :: tuple(),
      Chars :: string() | eof,
      RestChars :: string() | eof,
      TokensRet :: {ok, Tokens, EndLoc} |
                   {eof, EndLoc} |
                   ErrorInfo,
      Tokens :: [Token],
      Token :: term(),
      ErrorInfo :: {error, error_info(), erl_anno:location()},
      EndLoc :: erl_anno:location().
tokens(_Cont, _Chars) -> erlang:nif_error(undef).
-doc """
This is a re-entrant call to try and scan tokens from `Chars`.

If there are enough characters in `Chars` to either scan tokens or
detect an error then this will be returned with
`{done,...}`. Otherwise `{cont,Cont}` will be returned where `Cont` is
used in the next call to `tokens()` with more characters to try an
scan the tokens. This is continued until all tokens have been
scanned. `Cont` is initially `[]`.

This functions differs from `token` in that it will continue to scan tokens up
to and including an `{end_token,Token}` has been scanned (see next section). It
will then return all the tokens. This is typically used for scanning grammars
like Erlang where there is an explicit end token, `'.'`. If no end token is
found then the whole file will be scanned and returned. If an error occurs then
all tokens up to and including the next end token will be skipped.

It is not designed to be called directly by an application, but used through the
I/O system where it can typically be called in an application by:

```erlang
io:request(InFile, {get_until,unicode,Prompt,Module,tokens,[Loc]})
  -> TokensRet
```
""".
-doc(#{group => <<"Generated Scanner Exports">>}).
-spec tokens(Cont, Chars, StartLoc) ->
    {more, Cont1} | {done, TokensRet, RestChars} when
      Cont :: [] | Cont1,
      Cont1 :: tuple(),
      Chars :: string() | eof,
      RestChars :: string() | eof,
      TokensRet :: {ok, Tokens, EndLoc} |
                   {eof, EndLoc} |
                   ErrorInfo,
      Tokens :: [Token],
      Token :: term(),
      ErrorInfo :: {error, error_info(), erl_anno:location()},
      StartLoc :: erl_anno:location(),
      EndLoc :: erl_anno:location().
tokens(_Cont, _Chars, _StartLoc) -> erlang:nif_error(undef).

%%%
%%% Exported functions
%%%

%%% Interface to erl_compile.

-doc false.
compile(Input0, Output0,
        #options{warning = WarnLevel, verbose=Verbose, includes=Includes,
		 specific=Specific}) ->
    Input = assure_extension(shorten_filename(Input0), ".xrl"),
    Output = assure_extension(shorten_filename(Output0), ".erl"),
    Includefile = lists:sublist(Includes, 1),
    Werror = proplists:get_bool(warnings_as_errors, Specific),
    Deterministic = proplists:get_bool(deterministic, Specific),
    Opts = [{scannerfile,Output},{includefile,Includefile},{verbose,Verbose},
            {report_errors,true},{report_warnings,WarnLevel > 0},
	    {warnings_as_errors, Werror}, {deterministic, Deterministic}],
    case file(Input, Opts) of
        {ok, _} ->
            ok;
        error ->
            error
    end.

-doc """
The standard `t:error_info/0` structure that is returned from all I/O modules.
`ErrorDescriptor` is formattable by `format_error/1`.
""".
-type error_info() :: {erl_anno:line() | 'none',
                       module(), ErrorDescriptor :: term()}.
-type errors() :: [{file:filename(), [error_info()]}].
-type warnings() :: [{file:filename(), [error_info()]}].
-type ok_ret() :: {'ok', Scannerfile :: file:filename()}
                | {'ok', Scannerfile :: file:filename(), warnings()}.
-type error_ret() :: 'error'
                  | {'error', Errors :: errors(), Warnings :: warnings()}.
-type leex_ret() :: ok_ret() | error_ret().

-doc #{equiv => file(File, [])}.
-spec file(FileName) -> leex_ret() when
      FileName :: file:filename().

file(File) -> file(File, []).

-doc """
Generates a lexical analyzer from the definition in the input file.

The input file has the extension `.xrl`. This is added to the filename
if it is not given.  The resulting module is the Xrl filename without
the `.xrl` extension.

The current options are:

- **`dfa_graph`** - Generates a `.dot` file which contains a description of the
  DFA in a format which can be viewed with Graphviz, `www.graphviz.com`.

- **`{includefile,Includefile}`** - Uses a specific or customised prologue file
  instead of default `lib/parsetools/include/leexinc.hrl` which is otherwise
  included.

- **`{report_errors, boolean()}`** - Causes errors to be printed as they occur.
  Default is `true`.

- **`{report_warnings, boolean()}`** - Causes warnings to be printed as they
  occur. Default is `true`.

- **`{report, boolean()}`** - This is a short form for both `report_errors` and
  `report_warnings`.

- **`{return_errors, boolean()}`** - If this flag is set,
  `{error, Errors, Warnings}` is returned when there are errors. Default is
  `false`.

- **`{return_warnings, boolean()}`** - If this flag is set, an extra field
  containing `Warnings` is added to the tuple returned upon success. Default is
  `false`.

- **`{return, boolean()}`** - This is a short form for both `return_errors` and
  `return_warnings`.

- **`{scannerfile, Scannerfile}`** - `Scannerfile` is the name of the file that
  will contain the Erlang scanner code that is generated. The default (`""`) is
  to add the extension `.erl` to `FileName` stripped of the `.xrl` extension.

- **`{verbose, boolean()}`** - Outputs information from parsing the input file
  and generating the internal tables.

- **`{warnings_as_errors, boolean()}`** - Causes warnings to be treated as
  errors.

- **`{deterministic, boolean()}`** - Causes generated `-file()` attributes to only
  include the basename of the file path.

- **`{error_location, line | column}`** - If set to `column`, error location
  will be `{Line,Column}` tuple instead of just `Line`. Also, `StartLoc` and
  `EndLoc` in [`string/2`](`string/2`), [`token/3`](`token/3`), and
  [`tokens/3`](`tokens/3`) functions will be `{Line,Column}` tuple instead of
  just `Line`. Default is `line`. Note that you can use `TokenLoc` for token
  location independently, even if the `error_location` is set to `line`.

  Unicode characters are counted as many columns as they use bytes to represent.

- **`{tab_size, pos_integer()}`** - Sets the width of `\t` character (only
  relevant if `error_location` is set to `column`). Default is `8`.

Any of the Boolean options can be set to `true` by stating the name of the
option. For example, `verbose` is equivalent to `{verbose, true}`.

Leex will add the extension `.hrl` to the `Includefile` name and the extension
`.erl` to the `Scannerfile` name, unless the extension is already there.
""".
-doc(#{since => <<"OTP R16B02">>}).
-spec file(FileName, Options) -> leex_ret() when
      FileName :: file:filename(),
      Options :: Option | [Option],
      Option :: {'dfa_graph', boolean()}
              | {'includefile', Includefile :: file:filename()}
              | {'report_errors', boolean()}
              | {'report_warnings', boolean()}
              | {'report', boolean()}
              | {'return_errors', boolean()}
              | {'return_warnings', boolean()}
              | {'return', boolean()}
              | {'scannerfile', Scannerfile :: file:filename()}
              | {'verbose', boolean()}
              | {'warnings_as_errors', boolean()}
              | {'deterministic', boolean()}
              | {'error_location', line | column}
              | {'tab_size', pos_integer()}
              | 'dfa_graph'
              | 'report_errors' | 'report_warnings' | 'report'
              | 'return_errors' | 'return_warnings' | 'return'
              | 'verbose' | 'warnings_as_errors'.

file(File, Opts0) when is_list(Opts0) ->
    case is_filename(File) of
        no -> erlang:error(badarg, [File,Opts0]);
        _ -> ok
    end,
    EnvOpts0 = env_default_opts(),
    EnvOpts = select_recognized_opts(EnvOpts0),
    Opts1 = Opts0 ++ EnvOpts,
    Opts = case options(Opts1) of
               badarg ->
                   erlang:error(badarg, [File,Opts0]);
               Options ->
                   Options
           end,
    St0 = #leex{},
    St1 = filenames(File, Opts, St0),   % Get all the filenames
    St = try
             {ok,REAs,Actions,Code,St2} = parse_file(St1),
             {DFA,DF} = make_dfa(REAs, St2),
             case werror(St2) of
                 false ->
                     St3 = out_file(St2, DFA, DF, Actions, Code),
                     case lists:member(dfa_graph, St3#leex.opts) of
                         true -> out_dfa_graph(St3, DFA, DF);
                         false -> St3
                     end;
                 true ->
                     St2
             end
         catch #leex{}=St4 ->
             St4
         end,
    leex_ret(St);
file(File, Opt) ->
    file(File, [Opt]).

-doc """
Returns a descriptive string in English of an error reason `ErrorDescriptor`
returned by [`leex:file/1,2`](`file/1`) when there is an error in a regular
expression.
""".
-spec format_error(ErrorDescriptor) -> io_lib:chars() when
      ErrorDescriptor :: term().

format_error({file_error, Reason}) ->
    io_lib:fwrite("~ts",[file:format_error(Reason)]);
format_error(missing_defs) -> "missing Definitions";
format_error(missing_rules) -> "missing Rules";
format_error(missing_code) -> "missing Erlang code";
format_error(empty_rules) -> "no rules";
format_error(bad_rule) -> "bad rule";
format_error({regexp,E})->
    Es = case E of
             {interval_range,_} -> "interval range";
             {unterminated,Cs} ->
                 "unterminated " ++ Cs;
             {illegal_char,Cs} ->
                 "illegal character " ++ Cs;
%%           {posix_cc,What} ->
%%               ["illegal POSIX character class ",io_lib:write_string(What)];
             {char_class,What} ->
                 ["illegal character class ",io_lib:write_string(What)]
         end,
    ["bad regexp `",Es,"'"];
format_error(ignored_characters) ->
    "ignored characters";
format_error(cannot_parse) ->
    io_lib:fwrite("cannot parse; probably encoding mismatch", []).

%%%
%%% Local functions
%%%

assure_extension(File, Ext) ->
    lists:concat([strip_extension(File, Ext), Ext]).

%% Assumes File is a filename.
strip_extension(File, Ext) ->
    case filename:extension(File) of
        Ext -> filename:rootname(File);
        _Other -> File
    end.

%% Copied from compile.erl.
env_default_opts() ->
    Key = "ERL_COMPILER_OPTIONS",
    case os:getenv(Key) of
	false -> [];
	Str when is_list(Str) ->
	    case erl_scan:string(Str) of
		{ok,Tokens,_} ->
                    Dot = {dot, erl_anno:new(1)},
		    case erl_parse:parse_term(Tokens ++ [Dot]) of
			{ok,List} when is_list(List) -> List;
			{ok,Term} -> [Term];
			{error,_Reason} ->
			    io:format("Ignoring bad term in ~s\n", [Key]),
			    []
		    end;
		{error, {_,_,_Reason}, _} ->
		    io:format("Ignoring bad term in ~s\n", [Key]),
		    []
	    end
    end.

select_recognized_opts(Options0) ->
    Options = preprocess_options(Options0),
    AllOptions = all_options(),
    [Option ||
        {Name, _} = Option <- Options,
        lists:member(Name, AllOptions)].

options(Options0) ->
    Options1 = preprocess_options(Options0),
    AllOptions = all_options(),
    case check_options(Options1, AllOptions, []) of
        badarg ->
            badarg;
        OptionValues  ->
            AllOptionValues =
                [case lists:keyfind(Option, 1, OptionValues) of
                     false ->
                         {Option, default_option(Option)};
                     OptionValue ->
                         OptionValue
                 end || Option <- AllOptions],
            foldr(fun({_, false}, L) -> L;
                     ({Option, true}, L) -> [Option | L];
                     (OptionValue, L) -> [OptionValue | L]
                  end, [], AllOptionValues)
    end.

preprocess_options(Options) ->
    foldr(fun preproc_opt/2, [], Options).

preproc_opt(return, Os) ->
    [{return_errors, true}, {return_warnings, true} | Os];
preproc_opt(report, Os) ->
    [{report_errors, true}, {report_warnings, true} | Os];
preproc_opt({return, T}, Os) ->
    [{return_errors, T}, {return_warnings, T} | Os];
preproc_opt({report, T}, Os) ->
    [{report_errors, T}, {report_warnings, T} | Os];
preproc_opt(Option, Os) ->
    [try atom_option(Option) catch error:_ -> Option end | Os].

check_options([{Option, FileName0} | Options], AllOptions, L)
          when Option =:= includefile; Option =:= scannerfile ->
    case is_filename(FileName0) of
        no -> 
            badarg;
        Filename -> 
            check_options(Options, AllOptions, [{Option, Filename} | L])
    end;
check_options([{Option, Boolean} | Options], AllOptions, L)
          when is_boolean(Boolean) ->
    case lists:member(Option, AllOptions) of
        true ->
            check_options(Options, AllOptions, [{Option, Boolean} | L]);
        false ->
            badarg
        end;
check_options([{error_location, Loc}=O | Options], AllOptions, L)
        when Loc =:= line; Loc =:= column ->
    check_options(Options, AllOptions, [O | L]);
check_options([{tab_size, S}=O | Options], AllOptions, L)
        when is_integer(S) andalso S>0 ->
    check_options(Options, AllOptions, [O | L]);
check_options([], _AllOptions, L) ->
    L;
check_options(_Options, _, _L) ->
    badarg.

all_options() ->
    [dfa_graph,includefile,report_errors,report_warnings,
     return_errors,return_warnings,scannerfile,verbose,
     warnings_as_errors,deterministic,error_location,tab_size].

default_option(dfa_graph) -> false;
default_option(includefile) -> [];
default_option(report_errors) -> true;
default_option(report_warnings) -> true;
default_option(return_errors) -> false;
default_option(return_warnings) -> false;
default_option(scannerfile) -> [];
default_option(verbose) -> false;
default_option(warnings_as_errors) -> false;
default_option(deterministic) -> false;
default_option(error_location) -> line;
default_option(tab_size) -> 8.

atom_option(dfa_graph) -> {dfa_graph,true};
atom_option(report_errors) -> {report_errors,true};
atom_option(report_warnings) -> {report_warnings,true};
atom_option(warnings_as_errors) -> {warnings_as_errors,true};
atom_option(return_errors) -> {return_errors,true};
atom_option(verbose) -> {verbose,true};
atom_option(return_warnings) -> {return_warnings,true};
atom_option(deterministic) -> {deterministic,true};
atom_option(Key) -> Key.

is_filename(T) ->
    try filename:flatten(T)
    catch error: _ -> no
    end.    

shorten_filename(Name0) ->
    {ok,Cwd} = file:get_cwd(),
    case string:prefix(Name0, Cwd) of
        nomatch -> Name0;
        Rest ->
            case unicode:characters_to_list(Rest) of
                "/"++N -> N;
                N -> N
            end
    end.

leex_ret(St) ->
    report_errors(St),
    report_warnings(St),
    Es = pack_errors(St#leex.errors),
    Ws = pack_warnings(St#leex.warnings),
    Werror = werror(St),
    if 
        Werror ->
            do_error_return(St, Es, Ws);
        Es =:= [] -> 
            case member(return_warnings, St#leex.opts) of
                true -> {ok, St#leex.efile, Ws};
                false -> {ok, St#leex.efile}
            end;
        true ->
            do_error_return(St, Es, Ws)
    end.

do_error_return(St, Es, Ws) ->
    case member(return_errors, St#leex.opts) of
        true -> {error, Es, Ws};
        false -> error
    end.

werror(St) ->
    St#leex.warnings =/= []
	andalso member(warnings_as_errors, St#leex.opts).

pack_errors([{File,_} | _] = Es) ->
    [{File, flatmap(fun({_,E}) -> [E] end, sort(Es))}];
pack_errors([]) ->
    [].
    
pack_warnings([{File,_} | _] = Ws) ->
    [{File, flatmap(fun({_,W}) -> [W] end, sort(Ws))}];
pack_warnings([]) ->
    [].

report_errors(St) ->
    when_opt(fun () -> 
                     foreach(fun({File,{none,Mod,E}}) -> 
                                     io:fwrite("~ts: ~ts\n",
                                               [File,Mod:format_error(E)]);
                                ({File,{Line,Mod,E}}) -> 
                                     io:fwrite("~ts:~w: ~ts\n",
                                               [File,Line,Mod:format_error(E)])
                             end, sort(St#leex.errors))
             end, report_errors, St#leex.opts).

report_warnings(St) ->
    Werror = member(warnings_as_errors, St#leex.opts),
    Prefix = case Werror of
		 true -> "";
		 false -> "Warning: "
	     end,
    ReportWerror = Werror andalso member(report_errors, St#leex.opts),
    ShouldReport = member(report_warnings, St#leex.opts) orelse ReportWerror,
    when_bool(fun () ->
		      foreach(fun({File,{none,Mod,W}}) ->
				      io:fwrite("~ts: ~s~ts\n",
						[File,Prefix,
						 Mod:format_error(W)]);
				 ({File,{Line,Mod,W}}) ->
				      io:fwrite("~ts:~w: ~s~ts\n",
						[File,Line,Prefix,
						 Mod:format_error(W)])
			      end, sort(St#leex.warnings))
	      end, ShouldReport).

-spec add_error(_, #leex{}) -> no_return().
add_error(E, St) ->
    add_error(St#leex.xfile, E, St).

add_error(File, Error, St) ->
    throw(St#leex{errors = [{File,Error}|St#leex.errors]}).

add_warning(Line, W, St) ->
    St#leex{warnings = [{St#leex.xfile,{Line,leex,W}}|St#leex.warnings]}.

%% filenames(File, Options, State) -> State.
%%  The default output dir is the current directory unless an
%%  explicit one has been given in the options.

filenames(File, Opts, St0) ->
    Dir = filename:dirname(File),
    Base = filename:basename(File, ".xrl"),
    Xfile = filename:join(Dir, Base ++ ".xrl"),
    Efile = Base ++ ".erl",
    Gfile = Base ++ ".dot",
    Module = list_to_atom(Base),
    St1 = St0#leex{xfile=Xfile,
                   opts=Opts,
                   module=Module},
    {includefile,Ifile0} = lists:keyfind(includefile, 1, Opts),
    Ifile = inc_file_name(Ifile0),
    %% Test for explicit scanner file.
    {scannerfile,Ofile} = lists:keyfind(scannerfile, 1, Opts),
    if
        Ofile =:= [] ->
            St1#leex{efile=filename:join(Dir, Efile),
                     ifile=Ifile,
                     gfile=filename:join(Dir, Gfile)};
        true ->
            D = filename:dirname(Ofile),
            St1#leex{efile=Ofile,
                     ifile=Ifile,
                     gfile=filename:join(D, Gfile)}
    end.

when_opt(Do, Opt, Opts) ->
    case member(Opt, Opts) of
        true -> Do();
        false -> ok
    end.

when_bool(Do, Bool) ->
    case Bool of
	true -> Do();
	false -> ok
    end.

verbose_print(St, Format, Args) ->
    when_opt(fun () -> io:fwrite(Format, Args) end, verbose, St#leex.opts).

%% parse_file(State) -> {ok,[REA],[Action],Code,NewState} | throw(NewState)
%%  when
%%      REA = {RegExp,ActionNo};
%%      Action = {ActionNo,ActionString};
%%      Code = {StartLine, StartPos, NumOfLines}. Where the Erlang code is.
%%
%%  Read and parse the file Xfile.
%%  After each section of the file has been parsed we directly call the
%%  next section. This is done when we detect a line we don't recognise
%%  in the current section. The file format is very simple and Erlang
%%  token based, we allow empty lines and Erlang style comments.

parse_file(St0) ->
    case file:open(St0#leex.xfile, [read]) of
        {ok,Xfile} ->
            St1 = St0#leex{encoding = epp:set_encoding(Xfile)},
            try
                verbose_print(St1, "Parsing file ~ts, ", [St1#leex.xfile]),
                %% We KNOW that errors throw so we can ignore them here.
                {ok,Line1,St2} = parse_head(Xfile, St1),
                {ok,Line2,Macs,St3} = parse_defs(Xfile, Line1, St2),
                {ok,Line3,REAs,Actions,St4} =
                    parse_rules(Xfile, Line2, Macs, St3),
                {ok,Code,St5} = parse_code(Xfile, Line3, St4),
                verbose_print(St5, "contained ~w rules.~n", [length(REAs)]),
                {ok,REAs,Actions,Code,St5}
            after ok = file:close(Xfile)
            end;
        {error,Error} ->
            add_error({none,leex,{file_error,Error}}, St0)
    end.

%% parse_head(File, State) -> {ok,NextLine,State}.
%%  Parse the head of the file. Skip all comments and blank lines.

parse_head(Ifile, St) -> {ok,nextline(Ifile, 0, St),St}.

%% parse_defs(File, Line, State) -> {ok,NextLine,Macros,State}.
%%  Parse the macro definition section of a file. This must exist.
%%  The section is ended by a non-blank line which is not a macro def.

parse_defs(Ifile, {ok,?DEFS_HEAD ++ Rest,L}, St) ->
    St1 = warn_ignored_chars(L, Rest, St),
    parse_defs(Ifile, nextline(Ifile, L, St), [], St1);
parse_defs(_, {ok,_,L}, St) ->
    add_error({L,leex,missing_defs}, St);
parse_defs(_, {eof,L}, St) ->
    add_error({L,leex,missing_defs}, St).

parse_defs(Ifile, {ok,Chars,L}=Line, Ms, St) ->
    %% This little beauty matches out a macro definition, RE's are so clear.
    MS = "^[ \t]*([A-Z_][A-Za-z0-9_]*)[ \t]*=[ \t]*([^ \t\r\n]*)[ \t\r\n]*\$",
    case re:run(Chars, MS, [{capture,all_but_first,list},unicode]) of
        {match,[Name,Def]} ->
            %%io:fwrite("~p = ~p\n", [Name,Def]),
            parse_defs(Ifile, nextline(Ifile, L, St), [{Name,Def}|Ms], St);
        _ -> {ok,Line,Ms,St}                    % Anything else
    end;
parse_defs(_, Line, Ms, St) ->
    {ok,Line,Ms,St}.

%% parse_rules(File, Line, Macros, State) -> {ok,NextLine,REAs,Actions,State}.
%%  Parse the RE rules section of the file. This must exist.

parse_rules(Ifile, {ok,?RULE_HEAD ++ Rest,L}, Ms, St) ->
    St1 = warn_ignored_chars(L, Rest, St),
    parse_rules(Ifile, nextline(Ifile, L, St), Ms, [], [], 0, St1);
parse_rules(_, {ok,_,L}, _, St) ->
    add_error({L,leex,missing_rules}, St);
parse_rules(_, {eof,L}, _, St) ->
    add_error({L,leex,missing_rules}, St).

%% parse_rules(File, Result, Macros, RegExpActions, Actions, Acount, State) ->
%%      {ok,NextCLine,RegExpActions,Actions,NewState} | throw(NewState)

parse_rules(Ifile, NextLine, Ms, REAs, As, N, St) ->
    case NextLine of
        {ok,?CODE_HEAD ++ _Rest,_} ->
            parse_rules_end(Ifile, NextLine, REAs, As, St);
        {ok,Chars,L0} ->
            %%io:fwrite("~w: ~p~n", [L0,Chars]),
            case collect_rule(Ifile, Chars, L0) of
                {ok,Re,Atoks,L1} ->
                    {ok,REA,A,St1} = parse_rule(Re, L0, Atoks, Ms, N, St),
                    parse_rules(Ifile, nextline(Ifile, L1, St), Ms,
                                [REA|REAs], [A|As], N+1, St1);
                {error,E} -> add_error(E, St)
            end;
        {eof,_} ->
            parse_rules_end(Ifile, NextLine, REAs, As, St)
    end.

parse_rules_end(_, {ok,_,L}, [], [], St) ->
    add_error({L,leex,empty_rules}, St);
parse_rules_end(_, {eof,L}, [], [], St) ->
    add_error({L,leex,empty_rules}, St);
parse_rules_end(_, NextLine, REAs, As, St) ->
    %% Must be *VERY* careful to put rules in correct order!
    {ok,NextLine,reverse(REAs),reverse(As),St}.

%% collect_rule(File, Line, Lineno) ->
%%      {ok,RegExp,ActionTokens,NewLineno} | {error,E}.
%% Collect a complete rule by reading lines until the the regexp and
%% action has been read. Keep track of line number.

collect_rule(Ifile, Chars, L0) ->
    {RegExp,Rest} = string:take(Chars, " \t\r\n", true),
    case collect_action(Ifile, Rest, L0, []) of
        {ok,[{':',_}|Toks],L1} -> {ok,RegExp,Toks,L1};
        {ok,_,_} -> {error,{L0,leex,bad_rule}};
        {eof,L1} -> {error,{L1,leex,bad_rule}};
        {error,E,_} -> {error,E}
    end.

collect_action(_Ifile, {error, _}, L, _Cont0) ->
    {error, {L, leex, cannot_parse}, ignored_end_line};
collect_action(Ifile, Chars, L0, Cont0) ->
    case erl_scan:tokens(Cont0, Chars, L0) of
        {done,{ok,Toks,_},_} -> {ok,Toks,L0};
        {done,{eof,_},_} -> {eof,L0};
        {done,{error,E,_},_} -> {error,E,L0};
        {more,Cont1} ->
            collect_action(Ifile, io:get_line(Ifile, leex), L0+1, Cont1)
    end.

%% parse_rule(RegExpString, RegExpLine, ActionTokens, Macros, Counter, State) ->
%%      {ok,{RE,Action},ActionData,State}.
%%  Parse one regexp after performing macro substitution.

parse_rule(S, Line, [{dot,_}], Ms, N, St) ->
    case parse_rule_regexp(S, Ms, St) of
        {ok,R} ->
            {ok,{R,N},{N,empty_action},St};
        {error,E} ->
            add_error({Line,leex,E}, St)
    end;
parse_rule(S, Line, Atoks, Ms, N, St) ->
    case parse_rule_regexp(S, Ms, St) of
        {ok,R} ->
            %%io:fwrite("RE = ~p~n", [R]),
            %% Check for token variables.
            TokenChars = var_used('TokenChars', Atoks),
            TokenLen = var_used('TokenLen', Atoks),
            TokenLine = var_used('TokenLine', Atoks),
            TokenCol = var_used('TokenCol', Atoks),
            TokenLoc = var_used('TokenLoc', Atoks),
            {ok,{R,N},{N,Atoks,TokenChars,TokenLen,TokenLine,TokenCol,TokenLoc},St};
        {error,E} ->
            add_error({Line,leex,E}, St)
    end.

var_used(Name, Toks) ->
    case lists:keyfind(Name, 3, Toks) of
        {var,_,Name} -> true;                   %It's the var we want
        _ -> false
    end.

%% parse_rule_regexp(RegExpString, Macros, State) ->
%%     {ok,RegExp} | {error,Error}.
%% Substitute in macros and parse RegExpString. Cannot use re:replace
%% here as it uses info in replace string (&).

parse_rule_regexp(RE0, [{M,Exp}|Ms], St) ->
    Split= re:split(RE0, "\\{" ++ M ++ "\\}", [{return,list},unicode]),
    RE1 = lists:append(lists:join(Exp, Split)),
    parse_rule_regexp(RE1, Ms, St);
parse_rule_regexp(RE, [], St) ->
    %%io:fwrite("RE = ~p~n", [RE]),
    case re_parse(RE, St) of
        {ok,R} -> {ok,R};
        {error,E} -> {error,{regexp,E}}
    end.

%% parse_code(File, Line, State) -> {ok,Code,NewState}.
%%  Finds the line and the position where the code section of the file
%%  begins. This must exist.

parse_code(Ifile, {ok,?CODE_HEAD ++ Rest,CodeL}, St) ->
    St1 = warn_ignored_chars(CodeL, Rest, St),
    {ok, CodePos} = file:position(Ifile, cur),
    %% Just count the lines; copy the code from file to file later.
    EndCodeLine = count_lines(Ifile, CodeL, St),
    NCodeLines = EndCodeLine - CodeL,
    {ok,{CodeL,CodePos,NCodeLines},St1};
parse_code(_, {ok,_,L}, St) ->
    add_error({L,leex,missing_code}, St);
parse_code(_, {eof,L}, St) ->
    add_error({L,leex,missing_code}, St).

count_lines(File, N, St) ->
    case io:get_line(File, leex) of
        eof -> N;
        {error, _} -> add_error({N+1, leex, cannot_parse}, St);
        _Line -> count_lines(File, N+1, St)
    end.

%% nextline(InputFile, PrevLineNo, State) -> {ok,Chars,LineNo} | {eof,LineNo}.
%%  Get the next line skipping comment lines and blank lines.

nextline(Ifile, L, St) ->
    case io:get_line(Ifile, leex) of
        eof -> {eof,L};
        {error, _} -> add_error({L+1, leex, cannot_parse}, St);
        Chars ->
            case string:take(Chars, " \t\n") of
                {_, [$%|_Rest]} -> nextline(Ifile, L+1, St);
                {_, []} -> nextline(Ifile, L+1, St);
                _Other -> {ok,Chars,L+1}
            end
    end.

warn_ignored_chars(Line, S, St) ->
    case non_white(S) of
        [] -> St;
        _ -> add_warning(Line, ignored_characters, St)
    end.

non_white(S) ->
    [C || C <- S, C > $\s, C < $\200 orelse C > $\240].

%% This is the regular expression grammar used. It is equivalent to the
%% one used in AWK, except that we allow ^ $ to be used anywhere and fail
%% in the matching.
%%
%% reg -> alt : '$1'.
%% alt -> seq "|" seq ... : {alt,['$1','$2'...]}.
%% seq -> repeat repeat ... : {seq,['$1','$2'...]}.
%% repeat -> repeat "*" : {kclosure,'$1'}.
%% repeat -> repeat "+" : {pclosure,'$1'}.
%% repeat -> repeat "?" : {optional,'$1'}.
%% repeat -> repeat "{" [Min],[Max] "}" : {interval,'$1',Min,Max}
%% repeat -> single : '$1'.
%% single -> "(" reg ")" : {sub,'$2',Number}.
%% single -> "^" : bos/bol.
%% single -> "$" : eos/eol.
%% single -> "." : any.
%% single -> "[" class "]" : {char_class,char_class('$2')}
%% single -> "[" "^" class "]" : {comp_class,char_class('$3')}.
%% single -> "\"" chars "\"" : {lit,'$2'}.
%% single -> "\\" char : {lit,['$2']}.
%% single -> char : {lit,['$1']}.
%% single -> empty : epsilon.
%%  The grammar of the current regular expressions. The actual parser
%%  is a recursive descent implementation of the grammar.

%% re_parse(Chars, State) -> {ok,RegExp} | {error,Error}.

re_parse(Cs0, St) ->
    case catch re_reg(Cs0, 0, St) of
        {RE,_,[]} -> {ok,RE};
        {_,_,[C|_]} -> {error,{illegal_char,[C]}};
        {parse_error,E} -> {error,E}
    end.

parse_error(E) -> throw({parse_error,E}).

re_reg(Cs, Sn, St) -> re_alt(Cs, Sn, St).

re_alt(Cs0, Sn0, St) ->
    {L,Sn1,Cs1} = re_seq(Cs0, Sn0, St),
    case re_alt1(Cs1, Sn1, St) of
        {[],Sn2,Cs2} -> {L,Sn2,Cs2};
        {Rs,Sn2,Cs2} -> {{alt,[L|Rs]},Sn2,Cs2}
    end.

re_alt1([$||Cs0], Sn0, St) ->
    {L,Sn1,Cs1} = re_seq(Cs0, Sn0, St),
    {Rs,Sn2,Cs2} = re_alt1(Cs1, Sn1, St),
    {[L|Rs],Sn2,Cs2};
re_alt1(Cs, Sn, _) -> {[],Sn,Cs}.

%% Parse a sequence of regexps. Don't allow the empty sequence.
%% re_seq(Cs0, Sn0, St) ->
%%     {L,Sn1,Cs1} = repeat(Cs0, Sn0, St),
%%     case re_seq1(Cs1, Sn1, St) of
%%      {[],Sn2,Cs2} -> {L,Sn2,Cs2};
%%      {Rs,Sn2,Cs2} -> {{seq,[L|Rs]},Sn2,Cs2}
%%     end.

%% re_seq(Chars, SubNumber, State) -> {RegExp,SubNumber,Chars}.
%% Parse a sequence of regexps. Allow the empty sequence, returns epsilon.

re_seq(Cs0, Sn0, St) ->
    case re_seq1(Cs0, Sn0, St) of
        {[],Sn1,Cs1} -> {epsilon,Sn1,Cs1};
        {[R],Sn1,Cs1} -> {R,Sn1,Cs1};
        {Rs,Sn1,Cs1} -> {{seq,Rs},Sn1,Cs1}
    end.

re_seq1([C|_]=Cs0, Sn0, St) when C =/= $|, C =/= $) ->
    {L,Sn1,Cs1} = re_repeat(Cs0, Sn0, St),
    {Rs,Sn2,Cs2} = re_seq1(Cs1, Sn1, St),
    {[L|Rs],Sn2,Cs2};
re_seq1(Cs, Sn, _) -> {[],Sn,Cs}.

%% re_repeat(Chars, SubNumber, State) -> {RegExp,SubNumber,Chars}.

re_repeat(Cs0, Sn0, St) ->
    {S,Sn1,Cs1} = re_single(Cs0, Sn0, St),
    re_repeat1(Cs1, Sn1, S, St).

re_repeat1([$*|Cs], Sn, S, St) -> re_repeat1(Cs, Sn, {kclosure,S}, St);
re_repeat1([$+|Cs], Sn, S, St) -> re_repeat1(Cs, Sn, {pclosure,S}, St);
re_repeat1([$?|Cs], Sn, S, St) -> re_repeat1(Cs, Sn, {optional,S}, St);
%% { only starts interval when ere is true, otherwise normal character.
%% re_repeat1([${|Cs0], Sn, S, #leex{posix=true}=St) ->    % $}
%%     case re_interval_range(Cs0) of
%%         {Min,Max,[$}|Cs1]} when is_integer(Min), is_integer(Max), Min =< Max ->
%%             re_repeat1(Cs1, Sn, {interval,S,Min,Max}, St);
%%         {Min,Max,[$}|Cs1]} when is_integer(Min), is_atom(Max) ->
%%             re_repeat1(Cs1, Sn, {interval,S,Min,Max}, St);
%%         {_,_,Cs1} -> parse_error({interval_range,string_between([${|Cs0], Cs1)})
%%     end;
re_repeat1(Cs, Sn, S, _) -> {S,Sn,Cs}.

%% re_single(Chars, SubNumber, State) -> {RegExp,SubNumber,Chars}.
%% Parse a re_single regexp.

re_single([$(|Cs0], Sn0, St) ->                % $)
    Sn1 = Sn0 + 1,                             % Keep track of sub count anyway
    case re_reg(Cs0, Sn1, St) of
        {S,Sn2,[$)|Cs1]} -> {S,Sn2,Cs1};
        %%{S,Sn2,[$)|Cs1]} -> {{sub,S,Sn1},Sn2,Cs1};
        _ -> parse_error({unterminated,"("})
    end;
%% These are not legal inside a regexp.
%% re_single([$^|Cs], Sn, St) -> {bos,Sn,Cs};
%% re_single([$$|Cs], Sn, St) -> {eos,Sn,Cs};
%% re_single([$.|Cs], Sn, St) -> {any,Sn,Cs};
re_single([$.|Cs], Sn, _) -> {{comp_class,"\n"},Sn,Cs}; % Do this here?
re_single("[^" ++ Cs0, Sn, St) ->
    case re_char_class(Cs0, St) of
        {Cc,[$]|Cs1]} -> {{comp_class,Cc},Sn,Cs1};
        _ -> parse_error({unterminated,"["})
    end;
re_single([$[|Cs0], Sn, St) ->
    case re_char_class(Cs0, St) of
        {Cc,[$]|Cs1]} -> {{char_class,Cc},Sn,Cs1};
        _ -> parse_error({unterminated,"["})
    end;
re_single([$\\|Cs0], Sn, _) ->
    {C,Cs1} = re_char($\\, Cs0),
    {{lit,[C]},Sn,Cs1};
re_single([C|Cs0], Sn, St) ->
    case special_char(C, St) of
        true -> parse_error({illegal_char,[C]});
        false ->
            {C,Cs1} = re_char(C, Cs0),
            {{lit,[C]},Sn,Cs1}
    end.

-define(IS_HEX(C), C >= $0 andalso C =< $9 orelse
        C >= $A andalso C =< $F orelse
        C >= $a andalso C =< $f).

%% re_char(Char, Chars) -> {CharValue,Chars}.
%%  Reads one character value from the input list, it knows about escapes.

re_char($\\, [O1,O2,O3|S]) when
  O1 >= $0, O1 =< $7, O2 >= $0, O2 =< $7, O3 >= $0, O3 =< $7 ->
    {(O1*8 + O2)*8 + O3 - 73*$0,S};
re_char($\\, [$x,H1,H2|S]) when ?IS_HEX(H1), ?IS_HEX(H2) ->
    {erlang:list_to_integer([H1,H2], 16),S};
re_char($\\,[$x,${|S0]) -> 
    re_hex(S0, []);
re_char($\\,[$x|_]) ->
    parse_error({illegal_char,"\\x"});
re_char($\\, [C|S]) -> {escape_char(C),S};
re_char($\\, []) -> parse_error({unterminated,"\\"});
re_char(C, S) -> {C,S}.                         % Just this character

re_hex([C|Cs], L) when ?IS_HEX(C) -> re_hex(Cs, [C|L]);
re_hex([$}|S], L0) -> 
    L = lists:reverse(L0),
    case erlang:list_to_integer(L, 16) of
        C when C =< 16#10FFFF -> {C,S};
        _ -> parse_error({illegal_char,[$\\,$x,${|L]++"}"})
    end;
re_hex(_, _) -> parse_error({unterminated,"\\x{"}).

%% special_char(Char, State) -> bool().
%% These are the special characters for an ERE.
%% N.B. ]}) are only special in the context after [{(.

special_char($^, _) -> true;
special_char($., _) -> true;
special_char($[, _) -> true;
special_char($$, _) -> true;
special_char($(, _) -> true;
special_char($), _) -> true;
special_char($|, _) -> true;
special_char($*, _) -> true;
special_char($+, _) -> true;
special_char($?, _) -> true;
%% special_char(${, #leex{posix=true}) -> true;    % Only when POSIX set
special_char($\\, _) -> true;
special_char(_, _) -> false.

%% re_char_class(Chars, State) -> {CharClass,Chars}.
%% Parse a character class.

re_char_class([$]|Cs], St) ->                   % Must special case this.
    re_char_class(Cs, [$]], St);
re_char_class(Cs, St) -> re_char_class(Cs, [], St).

%% re_char_class("[:" ++ Cs0, Cc, #leex{posix=true}=St) ->
%%     %% POSIX char class only.
%%     case posix_cc(Cs0) of
%%         {Pcl,":]" ++ Cs1} -> re_char_class(Cs1, [{posix,Pcl}|Cc], St);
%%         {_,Cs1} -> parse_error({posix_cc,string_between(Cs0, Cs1)})
%%     end;
re_char_class([C1|Cs0], Cc, St) when C1 =/= $] ->
    case re_char(C1, Cs0) of
        {Cf,[$-,C2|Cs1]} when C2 =/= $] ->
            case re_char(C2, Cs1) of
                {Cl,Cs2} when Cf < Cl ->
                    re_char_class(Cs2, [{range,Cf,Cl}|Cc], St);
                {_,Cs2} ->
                    parse_error({char_class,string_between([C1|Cs0], Cs2)})
            end;
        {C,Cs1} -> re_char_class(Cs1, [C|Cc], St)
    end;
re_char_class(Cs, Cc, _) -> {reverse(Cc),Cs}.   % Preserve order

%% posix_cc(String) -> {PosixClass,RestString}.
%%  Handle POSIX character classes.

%% posix_cc("alnum" ++ Cs) -> {alnum,Cs};
%% posix_cc("alpha" ++ Cs) -> {alpha,Cs};
%% posix_cc("blank" ++ Cs) -> {blank,Cs};
%% posix_cc("cntrl" ++ Cs) -> {cntrl,Cs};
%% posix_cc("digit" ++ Cs) -> {digit,Cs};
%% posix_cc("graph" ++ Cs) -> {graph,Cs};
%% posix_cc("lower" ++ Cs) -> {lower,Cs};
%% posix_cc("print" ++ Cs) -> {print,Cs};
%% posix_cc("punct" ++ Cs) -> {punct,Cs};
%% posix_cc("space" ++ Cs) -> {space,Cs};
%% posix_cc("upper" ++ Cs) -> {upper,Cs};
%% posix_cc("xdigit" ++ Cs) -> {xdigit,Cs};
%% posix_cc(Cs) -> parse_error({posix_cc,string:slice(Cs, 0, 5)}).

escape_char($n) -> $\n;                         % \n = LF
escape_char($r) -> $\r;                         % \r = CR
escape_char($t) -> $\t;                         % \t = TAB
escape_char($v) -> $\v;                         % \v = VT
escape_char($b) -> $\b;                         % \b = BS
escape_char($f) -> $\f;                         % \f = FF
escape_char($e) -> $\e;                         % \e = ESC
escape_char($s) -> $\s;                         % \s = SPACE
escape_char($d) -> $\d;                         % \d = DEL
escape_char(C) -> C.                            % Pass it straight through

%% re_interval_range(Chars) -> {Min,Max,RestChars}.
%% NoInt     -> none,none
%% Int       -> Int,none
%% Int,      -> Int,any
%% Int1,Int2 -> Int1,Int2

%% re_interval_range(Cs0) ->
%%     case re_number(Cs0) of
%%         {none,Cs1} -> {none,none,Cs1};
%%         {N,[$,|Cs1]} ->
%%             case re_number(Cs1) of
%%                 {none,Cs2} -> {N,any,Cs2};
%%                 {M,Cs2} -> {N,M,Cs2}
%%             end;
%%         {N,Cs1} -> {N,none,Cs1}
%%     end.

%% re_number([C|Cs]) when C >= $0, C =< $9 ->
%%     re_number(Cs, C - $0);
%% re_number(Cs) -> {none,Cs}.

%% re_number([C|Cs], Acc) when C >= $0, C =< $9 ->
%%     re_number(Cs, 10*Acc + (C - $0));
%% re_number(Cs, Acc) -> {Acc,Cs}.

string_between(Cs1, Cs2) ->
    string:slice(Cs1, 0, string:length(Cs1)-string:length(Cs2)).

%% We use standard methods, Thompson's construction and subset
%% construction, to create first an NFA and then a DFA from the
%% regexps. A non-standard feature is that we work with sets of
%% character ranges (crs) instead sets of characters. This is most
%% noticeable when constructing DFAs. The major benefit is that we can
%% handle characters from any set, not just limited ASCII or 8859,
%% even 16/32 bit unicode.
%%
%% The whole range of characters is 0-maxchar, where maxchar is a BIG
%% number. We don't make any assumptions about the size of maxchar, it
%% is just bigger than any character.
%%
%% Using character ranges makes describing many regexps very simple,
%% for example the regexp "." just becomes the range
%% [{0-9},{11-maxchar}].

%% make_nfa(RegExpActions) -> {ok,{NFA,StartState}} | {error,E}.
%% Build a complete nfa from a list of {RegExp,Action}. The NFA field
%% accept has values {yes,Action}|no. The NFA is a list of states.

make_dfa(REAs, St) ->
    {NFA,NF} = build_combined_nfa(REAs),
    verbose_print(St, "NFA contains ~w states, ", [tuple_size(NFA)]),
    {DFA0,DF0} = build_dfa(NFA, NF),
    verbose_print(St, "DFA contains ~w states, ", [length(DFA0)]),
    {DFA,DF} = minimise_dfa(DFA0, DF0),
    verbose_print(St, "minimised to ~w states.~n", [length(DFA)]),
    %%io:fwrite("~p\n", [{NF,NFA}]),
    %%io:fwrite("~p\n", [{DF0,DFA0}]),
    %%io:fwrite("~p\n", [{DF,DFA}]),
    {DFA,DF}.

%% build_combined_nfa(RegExpActionList) -> {NFA,FirstState}.
%%  Build the combined NFA using Thompson's construction straight out
%%  of the book. Build the separate NFAs in the same order as the
%%  rules so that the accepting have ascending states have ascending
%%  state numbers. Start numbering the states from 1 as we put the
%%  states in a tuple with the state number as the index.
%%
%%  The edges from a state are a list of {CharRange,State} | {epsilon,State}.

build_combined_nfa(REAs) ->
    {NFA0,Firsts,Free} = build_nfa_list(REAs, [], [], 1),
    F = #nfa_state{no=Free,edges=epsilon_trans(Firsts)},
    {list_to_tuple(keysort(#nfa_state.no, [F|NFA0])),Free}.

build_nfa_list([{RE,Action}|REAs], NFA0, Firsts, Free0) ->
    {NFA1,Free1,First} = build_nfa(RE, Free0, Action),
    build_nfa_list(REAs, NFA1 ++ NFA0, [First|Firsts], Free1);
build_nfa_list([], NFA, Firsts, Free) ->
    {NFA,reverse(Firsts),Free}.

epsilon_trans(Firsts) -> [ {epsilon,F} || F <- Firsts ].

%% build_nfa(RegExp, NextState, Action) -> {NFA,NextState,FirstState}.
%%  When building the NFA states for a regexp we don't build the end
%%  state, just allocate a State for it and return this state's
%%  number. This allows us to avoid building unnecessary states for
%%  concatenation which would then have to be removed by overwriting
%%  an existing state.

build_nfa(RE, N0, Action) ->
    {NFA,N1,E} = build_nfa(RE, N0+1, N0, []),
    {[#nfa_state{no=E,accept={accept,Action}}|NFA],N1,N0}.

%% build_nfa(RegExp, NextState, FirstState, NFA) -> {NFA,NextState,EndState}.
%%  Build an NFA from the RegExp. NFA is a list of #nfa_state{} in no
%%  predefined order. NextState is the number of the next free state
%%  to use, FirstState is the the state which must be the start for
%%  this regexp as a previous regexp refers to it, EndState is the
%%  state to which this NFA will exit to. The number of the returned
%%  EndState is already allocated!

build_nfa({alt,REs}, N, F, NFA) ->
    build_nfa_alt(REs, N, F, NFA);
build_nfa({seq,REs}, N, F, NFA) ->
    build_nfa_seq(REs, N, F, NFA);
build_nfa({kclosure,RE}, N0, F, NFA0) ->
    {NFA1,N1,E1} = build_nfa(RE, N0+1, N0, NFA0),
    E = N1,                             % End state
    {[#nfa_state{no=F,edges=[{epsilon,N0},{epsilon,E}]},
      #nfa_state{no=E1,edges=[{epsilon,N0},{epsilon,E}]}|NFA1],
     N1+1,E};
build_nfa({pclosure,RE}, N0, F, NFA0) ->
    {NFA1,N1,E1} = build_nfa(RE, N0+1, N0, NFA0),
    E = N1,                             % End state
    {[#nfa_state{no=F,edges=[{epsilon,N0}]},
      #nfa_state{no=E1,edges=[{epsilon,N0},{epsilon,E}]}|NFA1],
     N1+1,E};
build_nfa({optional,RE}, N0, F, NFA0) ->
    {NFA1,N1,E1} = build_nfa(RE, N0+1, N0, NFA0),
    E = N1,                             % End state
    {[#nfa_state{no=F,edges=[{epsilon,N0},{epsilon,E}]},
      #nfa_state{no=E1,edges=[{epsilon,E}]}|NFA1],
     N1+1,E};
build_nfa({char_class,Cc}, N, F, NFA) ->
    {[#nfa_state{no=F,edges=[{pack_cc(Cc),N}]}|NFA],N+1,N};
build_nfa({comp_class,Cc}, N, F, NFA) ->
    {[#nfa_state{no=F,edges=[{comp_class(Cc),N}]}|NFA],N+1,N};
build_nfa({lit,Cs}, N, F, NFA) ->               % Implicit concatenation
    build_nfa_lit(Cs, N, F, NFA);
build_nfa(epsilon, N, F, NFA) ->                % Just an epsilon transition
    {[#nfa_state{no=F,edges=[{epsilon,N}]}|NFA],N+1,N}.

%% build_nfa_lit(Chars, NextState, FirstState, NFA) -> {NFA,NextState,EndState}.
%%  Build an NFA for the sequence of literal characters.

build_nfa_lit(Cs, N0, F0, NFA0) ->
    foldl(fun (C, {NFA,N,F}) ->
                  {[#nfa_state{no=F,edges=[{[{C,C}],N}]}|NFA],N+1,N}
          end, {NFA0,N0,F0}, Cs).

%% build_nfa_lit([C|Cs], N, F, NFA0) when is_integer(C) ->
%%     NFA1 = [#nfa_state{no=F,edges=[{[{C,C}],N}]}|NFA0],
%%     build_nfa_lit(Cs, N+1, N, NFA1);
%% build_nfa_lit([], N, F, NFA) -> {NFA,N,F}.

%% build_nfa_seq(REs, NextState, FirstState, NFA) -> {NFA,NextState,EndState}.
%%  Build an NFA for the regexps in a sequence.

build_nfa_seq(REs, N0, F0, NFA0) ->
    foldl(fun (RE, {NFA,N,F}) -> build_nfa(RE, N, F, NFA) end,
          {NFA0,N0,F0}, REs).

%% build_nfa_seq([RE|REs], N0, F, NFA0) ->
%%     {NFA1,N1,E1} = build_nfa(RE, N0, F, NFA0),
%%     build_nfa_seq(REs, N1, E1, NFA1);
%% build_nfa_seq([], N, F, NFA) -> {NFA,N,F}.

%% build_nfa_alt(REs, NextState, FirstState, NFA) -> {NFA,NextState,EndState}.
%%  Build an NFA for the regexps in an alternative. N.B. we don't
%%  handle empty alts here but the parser should never generate them
%%  anyway.

build_nfa_alt([RE], N, F, NFA) -> build_nfa(RE, N, F, NFA);
build_nfa_alt([RE|REs], N0, F, NFA0) ->
    {NFA1,N1,E1} = build_nfa(RE, N0+1, N0, NFA0),
    {NFA2,N2,E2} = build_nfa_alt(REs, N1+1, N1, NFA1),
    E = N2,                                     % End state
    {[#nfa_state{no=F,edges=[{epsilon,N0},{epsilon,N1}]},
      #nfa_state{no=E1,edges=[{epsilon,E}]},
      #nfa_state{no=E2,edges=[{epsilon,E}]}|NFA2],
     N2+1,E}.

%% build_nfa_alt(REs, NextState, FirstState, NFA) -> {NFA,NextState,EndState}.
%%  Build an NFA for the regexps in an alternative. Make one big
%%  epsilon split state, not necessary but fun.

%% build_nfa_alt(REs, N0, F0, NFA0) ->
%%     E = N0,                                  % Must reserve End state first
%%     {Fs,{NFA1,N1}} = mapfoldl(fun (RE, {NFA,N}) ->
%%                                    build_nfa_alt1(RE, N, E, NFA)
%%                            end, {NFA0,N0+1}, REs),
%%     {[#nfa_state{no=F0,edges=epsilon_trans(Fs)},
%%       #nfa_state{no=E,edges=[{epsilon,N1}]}|NFA1],N1+1,N1}.

%% build_nfa_alt1(RE, N0, End, NFA0) ->
%%     {NFA1,N1,E} = build_nfa(RE, N0+1, N0, NFA0),
%%     {N0,{[#nfa_state{no=E,edges=[{epsilon,End}]}|NFA1],N1}}.

%% pack_cc(CharClass) -> CharClass
%%  Pack and optimise a character class specification (bracket
%%  expression). First sort it and then compact it.

pack_cc(Cc) ->
    Crs = foldl(fun ({range,Cf,Cl}, Set) -> add_element({Cf,Cl}, Set);
                    (C, Set) -> add_element({C,C}, Set)
                end, ordsets:new(), Cc),
    pack_crs(Crs).                              % An ordset IS a list!

pack_crs([{C1,C2}=Cr,{C3,C4}|Crs]) when C1 =< C3, C2 >= C4 ->
    %% C1      C2
    %%   C3  C4
    pack_crs([Cr|Crs]);
pack_crs([{C1,C2},{C3,C4}|Crs]) when C2 >= C3, C2 < C4 ->
    %% C1    C2
    %%    C3   C4
    pack_crs([{C1,C4}|Crs]);
pack_crs([{C1,C2},{C3,C4}|Crs]) when C2 + 1 =:= C3 ->
    %% C1   C2
    %%        C3  C4
    pack_crs([{C1,C4}|Crs]);
pack_crs([Cr|Crs]) -> [Cr|pack_crs(Crs)];
pack_crs([]) -> [].

comp_class(Cc) ->
    Crs = pack_cc(Cc),
    Comp = comp_crs(Crs, 0),
    %% io:fwrite("comp: ~p\n      ~p\n", [Crs,Comp]),
    Comp.

comp_crs([{0,C2}|Crs], 0) ->                   % Get first range right
    comp_crs(Crs, C2+1);
comp_crs([{C1,C2}|Crs], Last) ->
    [{Last,C1-1}|comp_crs(Crs, C2+1)];
comp_crs([], Last) -> [{Last,maxchar}].

%% build_dfa(NFA, NfaFirstState) -> {DFA,DfaFirstState}.
%%  Build a DFA from an NFA using "subset construction". The major
%%  difference from the book is that we keep the marked and unmarked
%%  DFA states in separate lists. New DFA states are added to the
%%  unmarked list and states are marked by moving them to the marked
%%  list. We assume that the NFA accepting state numbers are in
%%  ascending order for the rules and use ordsets to keep this order.

build_dfa(NFA, Nf) ->
    D = #dfa_state{no=0,nfa=eclosure([Nf], NFA)},
    {build_dfa([D], 1, [], NFA),0}.

%% build_dfa([UnMarked], NextState, [Marked], NFA) -> DFA.
%%  Traverse the unmarked states. Temporarily add the current unmarked
%%  state to the marked list before calculating translation, this is
%%  to avoid adding too many duplicate states. Add it properly to the
%%  marked list afterwards with correct translations.

build_dfa([U|Us0], N0, Ms, NFA) ->
    {Ts,Us1,N1} = build_dfa(U#dfa_state.nfa, Us0, N0, [], [U|Ms], NFA),
    M = U#dfa_state{trans=Ts,accept=accept(U#dfa_state.nfa, NFA)},
    build_dfa(Us1, N1, [M|Ms], NFA);
build_dfa([], _, Ms, _) -> Ms.

%% build_dfa([NfaState], [Unmarked], NextState, [Transition], [Marked], NFA) ->
%%      {Transitions,UnmarkedStates,NextState}.
%%  Foreach NFA state set calculate the legal translations. N.B. must
%%  search *BOTH* the unmarked and marked lists to check if DFA state
%%  already exists. As the range of characters is potentially VERY
%%  large we cannot explicitly test all characters. Instead we first
%%  calculate the set of all disjoint character ranges which are
%%  possible candidates to the set of NFA states. The transitions are
%%  an orddict so we get the transition lists in ascending order.

build_dfa(Set, Us, N, Ts, Ms, NFA) ->
    %% List of all transition sets.
    Crs0 = [Cr || S <- Set,
                  {Crs,_St} <- (element(S, NFA))#nfa_state.edges,
                  Crs =/= epsilon,       % Not an epsilon transition
                  Cr <- Crs ],
    Crs1 = lists:usort(Crs0),            % Must remove duplicates!
    %% Build list of disjoint test ranges.
    Test = disjoint_crs(Crs1),
    %% io:fwrite("bd: ~p\n    ~p\n    ~p\n    ~p\n", [Set,Crs0,Crs1,Test]),
    build_dfa(Test, Set, Us, N, Ts, Ms, NFA).

%% disjoint_crs([CharRange]) -> [CharRange].
%%  Take a sorted list of char ranges and make a sorted list of
%%  disjoint char ranges. No new char range extends past an existing
%%  char range.

disjoint_crs([{_C1,C2}=Cr1,{C3,_C4}=Cr2|Crs]) when C2 < C3 ->
    %% C1  C2
    %%        C3  C4
    [Cr1|disjoint_crs([Cr2|Crs])];
disjoint_crs([{C1,C2},{C3,C4}|Crs]) when C1 =:= C3 ->
    %% C1     C2
    %% C3       C4
    [{C1,C2}|disjoint_crs(add_element({C2+1,C4}, Crs))];
disjoint_crs([{C1,C2},{C3,C4}|Crs]) when C1 < C3, C2 >= C3, C2 < C4 ->
    %% C1     C2
    %%    C3     C4
    [{C1,C3-1}|disjoint_crs(union([{C3,C2},{C2+1,C4}], Crs))];
disjoint_crs([{C1,C2},{C3,C4}|Crs]) when C1 < C3, C2 =:= C4 ->
    %% C1      C2
    %%    C3   C4
    [{C1,C3-1}|disjoint_crs(add_element({C3,C4}, Crs))];
disjoint_crs([{C1,C2},{C3,C4}|Crs]) when C1 < C3, C2 > C4 ->
    %% C1        C2
    %%    C3   C4
    [{C1,C3-1}|disjoint_crs(union([{C3,C4},{C4+1,C2}], Crs))];
disjoint_crs([Cr|Crs]) -> [Cr|disjoint_crs(Crs)];
disjoint_crs([]) -> [].

build_dfa([Cr|Crs], Set, Us, N, Ts, Ms, NFA) ->
    case eclosure(move(Set, Cr, NFA), NFA) of
        S when S =/= [] ->
            case dfa_state_exist(S, Us, Ms) of
                {yes,T} ->
                    build_dfa(Crs, Set, Us, N, store(Cr, T, Ts), Ms, NFA);
                no ->
                    U = #dfa_state{no=N,nfa=S},
                    build_dfa(Crs, Set, [U|Us], N+1, store(Cr, N, Ts), Ms, NFA)
            end;
        [] ->
            build_dfa(Crs, Set, Us, N, Ts, Ms, NFA)
    end;
build_dfa([], _, Us, N, Ts, _, _) ->
    {Ts,Us,N}.

%% dfa_state_exist(Set, Unmarked, Marked) -> {yes,State} | no.

dfa_state_exist(S, Us, Ms) ->
    case lists:keyfind(S, #dfa_state.nfa, Us) of
        #dfa_state{no=T} -> {yes,T};
        false ->
            case lists:keyfind(S, #dfa_state.nfa, Ms) of
                #dfa_state{no=T} -> {yes,T};
                false -> no
            end
    end.

%% eclosure([State], NFA) -> [State].
%% move([State], Char, NFA) -> [State].
%%  These are straight out of the book. As eclosure uses ordsets then
%%  the generated state sets are in ascending order.

eclosure(Sts, NFA) -> eclosure(Sts, NFA, []).

eclosure([St|Sts], NFA, Ec) ->
    #nfa_state{edges=Es} = element(St, NFA),
    eclosure([ N || {epsilon,N} <- Es,
		    not is_element(N, Ec) ] ++ Sts,
             NFA, add_element(St, Ec));
eclosure([], _, Ec) -> Ec.

move(Sts, Cr, NFA) ->
    %% io:fwrite("move1: ~p\n", [{Sts,Cr}]),
    [ St || N <- Sts,
            {Crs,St} <- (element(N, NFA))#nfa_state.edges,
            Crs =/= epsilon,             % Not an epsilon transition
            in_crs(Cr, Crs) ].

in_crs({C1,C2}, [{C3,C4}|_Crs]) when C1 >= C3, C2 =< C4 -> true;
in_crs(Cr, [Cr|_Crs]) -> true;          % Catch bos and eos.
in_crs(Cr, [_|Crs]) -> in_crs(Cr, Crs);
in_crs(_Cr, []) -> false.

%% accept([State], NFA) -> {accept,A} | noaccept.
%%  Scan down the state list until we find an accepting state.

accept([St|Sts], NFA) ->
    case element(St, NFA) of
        #nfa_state{accept={accept,A}} -> {accept,A};
        #nfa_state{accept=noaccept} -> accept(Sts, NFA)
    end;
accept([], _) -> noaccept.

%% minimise_dfa(DFA, DfaFirst) -> {DFA,DfaFirst}.
%%  Minimise the DFA by removing equivalent states. We consider a
%%  state if both the transitions and the their accept state is the
%%  same.  First repeatedly run through the DFA state list removing
%%  equivalent states and updating remaining transitions with
%%  remaining equivalent state numbers. When no more reductions are
%%  possible then pack the remaining state numbers to get consecutive
%%  states.

minimise_dfa(DFA0, Df0) ->
    case min_dfa(DFA0) of
        {DFA1,[]} ->                    % No reduction!
            {DFA2,Rs} = pack_dfa(DFA1),
            {min_update(DFA2, Rs),min_use(Df0, Rs)};
        {DFA1,Rs} ->
            minimise_dfa(min_update(DFA1, Rs), min_use(Df0, Rs))
    end.

min_dfa(DFA) -> min_dfa(DFA, [], []).

min_dfa([D|DFA0], Rs0, MDFA) ->
    {DFA1,Rs1} = min_delete(DFA0, D#dfa_state.trans, D#dfa_state.accept,
                            D#dfa_state.no, Rs0, []),
    min_dfa(DFA1, Rs1, [D|MDFA]);
min_dfa([], Rs, MDFA) -> {MDFA,Rs}.

%% min_delete(States, Trans, Action, NewN, Rs, MiniDFA) -> {MiniDFA,Rs}.
%%  Delete all states with same transactions and action. Return
%%  rewrites and minimised DFA with no duplicate states.

min_delete([#dfa_state{no=N,trans=T,accept=A}|DFA], T, A, NewN, Rs, MDFA) ->
    min_delete(DFA, T, A, NewN, [{N,NewN}|Rs], MDFA);
min_delete([D|DFA], T, A, NewN, Rs, MDFA) ->
    min_delete(DFA, T, A, NewN, Rs, [D|MDFA]);
min_delete([], _, _, _, Rs, MDFA) -> {MDFA,Rs}.

min_update(DFA, Rs) ->
    [ D#dfa_state{trans=min_update_trans(D#dfa_state.trans, Rs)} || D <- DFA ].

min_update_trans(Tr, Rs) ->
    [ {C,min_use(S, Rs)} || {C,S} <- Tr ].

min_use(Old, [{Old,New}|_]) -> New;
min_use(Old, [_|Reds]) -> min_use(Old, Reds);
min_use(Old, []) -> Old.

pack_dfa(DFA) -> pack_dfa(DFA, 0, [], []).

pack_dfa([D|DFA], NewN, Rs, PDFA) ->
    pack_dfa(DFA, NewN+1,
             [{D#dfa_state.no,NewN}|Rs], [D#dfa_state{no=NewN}|PDFA]);
pack_dfa([], _, Rs, PDFA) -> {PDFA,Rs}.

%% The main output is the yystate function which is built from the
%% DFA. It has the spec:
%%
%% yystate() -> InitialState.
%% yystate(State, InChars, Line, CurrTokLen, AcceptAction, AcceptLen) ->
%%      {Action, AcceptLength, RestChars, Line} |         Accepting end state
%%      {Action, AcceptLength, RestChars, Line, State} |  Accepting state
%%      {reject, AcceptLength, CurrTokLen, RestChars, Line, State} |
%%      {Action, AcceptLength, CurrTokLen, RestChars, Line, State}.

%% The return CurrTokLen is always the current number of characters
%% scanned in the current token. The returns have the following
%% meanings:
%% {Action, AcceptLength, RestChars, Line} -
%%  The scanner has reached an accepting end-state, for example after
%%  a regexp "abc". Action is the action number and AcceptLength is
%%  the length of the matching token.
%%
%% {Action, AcceptLength, RestChars, Line, State} -
%%  The scanner has reached an accepting transition state, for example
%%  after c in regexp "abc(xyz)?", continuation depends on
%%  RestChars. If RestChars == [] (no more current characters) then we
%%  need to get more characters to see if it is an end-state,
%%  otherwise (eof or chars) then we have not found continuing
%%  characters and it is an end state.
%%
%% {reject, AcceptLength, CurrTokLen, RestChars, Line, State} -
%% {Action, AcceptLength, CurrTokLen, RestChars, Line, State} -
%%  The scanner has reached a non-accepting transition state. If
%%  RestChars == [] we need to get more characters to continue.
%%  Otherwise if 'reject' then no accepting state has been reached it
%%  is an error. If we have an Action and AcceptLength then these are
%%  the last accept state, use them and continue from there.

%% out_file(LeexState, DFA, DfaStart, [Action], Code) -> ok | error.
%%  Generate an output .erl file from the include file, the DFA and
%%  the code for the actions.

out_file(St0, DFA, DF, Actions, Code) ->
    verbose_print(St0, "Writing file ~ts, ", [St0#leex.efile]),
    case open_inc_file(St0) of
        {ok,Ifile} ->
            try
                case file:open(St0#leex.efile, [write]) of
                    {ok,Ofile} ->
                        set_encoding(St0, Ofile),
                        try 
                            output_encoding_comment(Ofile, St0),
                            Deterministic = proplists:get_bool(deterministic, St0#leex.opts),
                            output_file_directive(Ofile, St0#leex.ifile, Deterministic, 0),
                            out_file(Ifile, Ofile, St0, DFA, DF, Actions,
                                     Code, 1),
                            verbose_print(St0, "ok~n", []),
                            St0
                        after ok = file:close(Ofile)
                        end;
                    {error,Error} ->
                        verbose_print(St0, "error~n", []),
                        add_error({none,leex,{file_error,Error}}, St0)
                end
            after ok = file:close(Ifile)
            end;
        {{error,Error},Ifile} ->
            add_error(Ifile, {none,leex,{file_error,Error}}, St0)
    end.

open_inc_file(State) ->
    Ifile = State#leex.ifile,
    case file:open(Ifile, [read]) of
        {ok,F} ->
            _ = epp:set_encoding(F),
            {ok,F};
        Error -> {Error,Ifile}
    end.

inc_file_name([]) ->
    Incdir = filename:join(code:lib_dir(parsetools), "include"),
    filename:join(Incdir, ?LEEXINC);
inc_file_name(Filename) ->
    Filename.
                    
%% out_file(IncFile, OutFile, State, DFA, DfaStart, Actions, Code, Line) -> ok
%%  Copy the include file line by line substituting special lines with
%%  generated code. We cheat by only looking at the first 5
%%  characters.

out_file(Ifile, Ofile, St, DFA, DF, Actions, Code, L) ->
    Deterministic = proplists:get_bool(deterministic, St#leex.opts),
    case io:get_line(Ifile, leex) of
        eof ->
            output_file_directive(Ofile, St#leex.ifile, Deterministic, L);
        {error, _} ->
            add_error(St#leex.ifile, {L, leex, cannot_parse}, St);
        Line ->
            case string:slice(Line, 0, 5) of
                "##mod" -> out_module(Ofile, St);
                "##cod" -> out_erlang_code(Ofile, St, Code, L);
                "##str" -> out_string(Ofile, St#leex.opts);
                "##tkn" -> out_token(Ofile, St#leex.opts);
                "##tks" -> out_tokens(Ofile, St#leex.opts);
                "##tab" -> out_tab_size(Ofile, St#leex.opts);
                "##dfa" -> out_dfa(Ofile, St, DFA, Code, DF, L);
                "##act" -> out_actions(Ofile, St#leex.xfile, Deterministic, Actions);
                _ -> io:put_chars(Ofile, Line)
            end,
            out_file(Ifile, Ofile, St, DFA, DF, Actions, Code, L+1)
    end.

out_module(File, St) ->
    io:fwrite(File, "-module(~w).\n", [St#leex.module]).

out_erlang_code(File, St, Code, L) ->
    {CodeL,CodePos,_NCodeLines} = Code,
    Deterministic = proplists:get_bool(deterministic, St#leex.opts),
    output_file_directive(File, St#leex.xfile, Deterministic, CodeL),
    {ok,Xfile} = file:open(St#leex.xfile, [read]),
    try
        set_encoding(St, Xfile),
        {ok,_} = file:position(Xfile, CodePos),
        ok = file_copy(Xfile, File)
    after 
        ok = file:close(Xfile)
    end,
    io:nl(File),
    output_file_directive(File, St#leex.ifile, Deterministic, L).

out_tab_size(File, Opts) ->
    Size = proplists:get_value(tab_size, Opts),
    io:fwrite(File, "tab_size() -> ~p.\n", [Size]).

%% Exclude column number if needed
out_string(File, Opts) ->
    out_string_1(File, Opts),
    out_string_2(File, Opts),
    Vars = lists:join(", ",["Ics","L0","C0","Tcs","Ts"]),
    out_head(File,string,Vars),
    EL = proplists:get_value(error_location, Opts),
    case EL of
        column ->
            io:fwrite(File,"    do_string(~s).\n",[Vars]);
        line ->
            io:fwrite(File,"    case do_string(~s) of\n",[Vars]),
            io:fwrite(File,"        {ok, T, {L,_}} -> {ok, T, L};\n",[]),
            io:fwrite(File,"        {error, {{EL,_},M,D}, {L,_}} ->\n",[]),
            io:fwrite(File,"            EI = {EL,M,D},\n",[]),
            io:fwrite(File,"            {error, EI, L}\n",[]),
            io:fwrite(File,"    end.\n",[])
    end.

out_string_1(File, Opts) ->
    out_head(File,string,"Ics"),
    EL = proplists:get_value(error_location, Opts),
    DefLoc = case EL of
                column -> "{1,1}";
                line   -> "1"
    end,
    io:fwrite(File,"    string(~s).\n",["Ics,"++DefLoc]).

out_string_2(File, Opts) ->
    EL = proplists:get_value(error_location, Opts),
    case EL of
        column ->
            out_head(File,string,"Ics,{L0,C0}"),
            CallVars = lists:join(", ", ["Ics","L0","C0","Ics","[]"]),
            io:fwrite(File,"    string(~s).\n",[CallVars]);
        line ->
            out_head(File,string,"Ics,L0"),
            CallVars = lists:join(", ", ["Ics","L0","1","Ics","[]"]),
            io:fwrite(File,"    string(~s).\n",[CallVars])
    end.

out_token(File, Opts) ->
    out_tokens_wrapper(File, Opts, token).

out_tokens(File, Opts) ->
    out_tokens_wrapper(File, Opts, tokens).

out_tokens_wrapper(File, Opts, Fun) ->
    out_token_2(File, Opts, Fun),
    EL = proplists:get_value(error_location, Opts),
    case EL of
        column ->
            VarsCol = lists:join(", ",["Cont","Chars","{Line,Col}"]),
            out_head(File, Fun, VarsCol),
            io:fwrite(File,"    do_~s(~s).\n",[Fun,"Cont,Chars,Line,Col"]);
        line ->
            VarsCol = lists:join(", ",["Cont","Chars","Line"]),
            out_head(File, Fun, VarsCol),
            io:fwrite(File,"    case do_~s(~s) of\n",[Fun,"Cont,Chars,Line,1"]),
            io:fwrite(File,"        {more, _} = C -> C;\n",[]),
            io:fwrite(File,"        {done, Ret0, R} ->\n",[]),
            io:fwrite(File,"            Ret1 = case Ret0 of\n",[]),
            io:fwrite(File,"                {ok, T, {L,_}} -> {ok, T, L};\n",[]),
            io:fwrite(File,"                {eof, {L,_}} -> {eof, L};\n",[]),
            io:fwrite(File,"                {error, {{EL,_},M,D},{L,_}} -> {error, {EL,M,D},L}\n",[]),
            io:fwrite(File,"            end,\n",[]),
            io:fwrite(File,"            {done, Ret1, R}\n",[]),
            io:fwrite(File,"    end.\n",[])
    end.

out_token_2(File, Opts, Fun) ->
    out_head(File, Fun, "Cont,Chars"),
    EL = proplists:get_value(error_location, Opts),
    DefLoc = case EL of
        column -> "{1,1}";
        line   -> "1"
    end,
    io:fwrite(File,"    ~s(~s).\n",[Fun,"Cont,Chars,"++DefLoc]).

out_head(File, Fun, Vars) ->
    io:fwrite(File, "~s(~s) -> \n",[Fun,Vars]).

file_copy(From, To) ->
    case io:get_line(From, leex) of
        eof -> ok;
        Line when is_list(Line) ->
            io:fwrite(To, "~ts", [Line]),
            file_copy(From, To)
    end.

out_dfa(File, St, DFA, Code, DF, L) ->
    {_CodeL,_CodePos,NCodeLines} = Code,
    Deterministic = proplists:get_bool(deterministic, St#leex.opts),
    %% Three file attributes before this one...
    output_file_directive(File, St#leex.efile, Deterministic, L+(NCodeLines-1)+3),
    io:fwrite(File, "yystate() -> ~w.~n~n", [DF]),
    foreach(fun (S) -> out_trans(File, S) end, DFA),
    io:fwrite(File, "yystate(S, Ics, Line, Col, Tlen, Action, Alen) ->~n", []),
    io:fwrite(File, "    {Action,Alen,Tlen,Ics,Line,Col,S}.~n", []).

out_trans(File, #dfa_state{no=N,trans=[],accept={accept,A}}) ->
    %% Accepting end state, guaranteed done.
    io:fwrite(File, "yystate(~w, Ics, Line, Col, Tlen, _, _) ->~n", [N]),
    io:fwrite(File, "    {~w,Tlen,Ics,Line,Col};~n", [A]);
out_trans(File, #dfa_state{no=N,trans=Tr,accept={accept,A}}) ->
    %% Accepting state, but there maybe more.
    foreach(fun (T) -> out_accept_tran(File, N, A, T) end, pack_trans(Tr)),
    io:fwrite(File, "yystate(~w, Ics, Line, Col, Tlen, _, _) ->~n", [N]),
    io:fwrite(File, "    {~w,Tlen,Ics,Line,Col,~w};~n", [A,N]);
out_trans(File, #dfa_state{no=N,trans=Tr,accept=noaccept}) ->
    %% Non-accepting transition state.
    foreach(fun (T) -> out_noaccept_tran(File, N, T) end, pack_trans(Tr)),
    io:fwrite(File, "yystate(~w, Ics, Line, Col, Tlen, Action, Alen) ->~n", [N]),
    io:fwrite(File, "    {Action,Alen,Tlen,Ics,Line,Col,~w};~n", [N]).

out_accept_tran(File, N, A, {{Cf,maxchar},S}) ->
    out_accept_head_max(File, N, Cf),
    out_accept_body(File, S, "Line", "Col", A);
out_accept_tran(File, N, A, {{Cf,Cl},S}) ->
    out_accept_head_range(File, N, Cf, Cl),
    out_accept_body(File, S, "Line", "Col", A);
out_accept_tran(File, N, A, {$\n,S}) ->
    out_accept_head_1(File, N, $\n),
    out_accept_body(File, S, "Line+1", "1", A);
out_accept_tran(File, N, A, {C,S}) ->
    out_accept_head_1(File, N, C),
    out_accept_body(File, S, "Line", "Col", A).

out_accept_head_1(File, State, Char) ->
    out_head_1(File, State, Char, "_", "_").

out_accept_head_max(File, State, Min) ->
    out_head_max(File, State, Min, "_", "_").

out_accept_head_range(File, State, Min, Max) ->
    out_head_range(File, State, Min, Max, "_", "_").

out_accept_body(File, Next, Line, Col, Action) ->
    out_body(File, Next, Line, Col, io_lib:write(Action), "Tlen").

out_noaccept_tran(File, N, {{Cf,maxchar},S}) ->
    out_noaccept_head_max(File, N, Cf),
    out_noaccept_body(File, S, "Line", "Col");
out_noaccept_tran(File, N, {{Cf,Cl},S}) ->
    out_noaccept_head_range(File, N, Cf, Cl),
    out_noaccept_body(File, S, "Line", "Col");
out_noaccept_tran(File, N, {$\n,S}) ->
    out_noaccept_head_1(File, N, $\n),
    out_noaccept_body(File, S, "Line+1", "1");
out_noaccept_tran(File, N, {C,S}) ->
    out_noaccept_head_1(File, N, C),
    out_noaccept_body(File, S, "Line", "Col").

out_noaccept_head_1(File, State, Char) ->
    out_head_1(File, State, Char, "Action", "Alen").

out_noaccept_head_max(File, State, Min) ->
    out_head_max(File, State, Min, "Action", "Alen").

out_noaccept_head_range(File, State, Min, Max) ->
    out_head_range(File, State, Min, Max, "Action", "Alen").

out_noaccept_body(File, Next, Line, Col) ->
    out_body(File, Next, Line, Col, "Action", "Alen").

out_head_1(File, State, Char = $\n, Action, Alen) ->
    io:fwrite(File, "yystate(~w, [~w|Ics], Line, _, Tlen, ~s, ~s) ->\n",
                [State,Char,Action,Alen]);
out_head_1(File, State, Char, Action, Alen) ->
    io:fwrite(File, "yystate(~w, [~w|Ics], Line, Col, Tlen, ~s, ~s) ->\n",
              [State,Char,Action,Alen]).

out_head_max(File, State, Min, Action, Alen) ->
    io:fwrite(File, "yystate(~w, [C|Ics], Line, Col, Tlen, ~s, ~s) when C >= ~w ->\n",
              [State,Action,Alen,Min]).

out_head_range(File, State, Min, Max, Action, Alen) ->
    io:fwrite(File, "yystate(~w, [C|Ics], Line, Col, Tlen, ~s, ~s) when C >= ~w, C =< ~w ->\n",
              [State,Action,Alen,Min,Max]).

out_body(File, Next, Line, Col, Action, Alen) ->
    io:fwrite(File, "    yystate(~w, Ics, ~s, ~s, Tlen+1, ~s, ~s);\n",
              [Next,Line,Col,Action,Alen]).

%% pack_trans([{Crange,State}]) -> [{Crange,State}] when
%%      Crange = {Char,Char} | Char.
%%  Pack the translation table into something more suitable for
%%  generating code. We KNOW how the pattern matching compiler works
%%  so solitary characters are stored before ranges. We do this by
%%  prepending singletons to the front of the packed transitions and
%%  appending ranges to the back. This preserves the smallest to
%%  largest order of ranges. Newline characters, $\n, are always
%%  extracted and handled as singeltons.

pack_trans(Trs) -> pack_trans(Trs, []).

%% pack_trans(Trs) ->
%%     Trs1 = pack_trans(Trs, []),
%%     io:fwrite("tr:~p\n=> ~p\n", [Trs,Trs1]),
%%     Trs1.

pack_trans([{{C,C},S}|Trs], Pt) ->         % Singletons to the head
    case lists:member({C,S}, Pt) of
        true -> pack_trans(Trs, Pt);
        false -> pack_trans(Trs, [{C,S}|Pt])
    end;
%% Special detection and handling of $\n.
pack_trans([{{Cf,$\n},S}|Trs], Pt) ->
    pack_trans([{{Cf,$\n-1},S}|Trs], [{$\n,S}|Pt]);
pack_trans([{{$\n,Cl},S}|Trs], Pt) ->
    pack_trans([{{$\n+1,Cl},S}|Trs], [{$\n,S}|Pt]);
pack_trans([{{Cf,Cl},S}|Trs], Pt) when Cf < $\n, Cl > $\n ->
    pack_trans([{{Cf,$\n-1},S},{{$\n+1,Cl},S}|Trs], [{$\n,S}|Pt]);
%% Small ranges become singletons.
pack_trans([{{Cf,Cl},S}|Trs], Pt) when Cl =:= Cf + 1 ->
    pack_trans(Trs, [{Cf,S},{Cl,S}|Pt]);
pack_trans([Tr|Trs], Pt) ->                % The default uninteresting case
    pack_trans(Trs, Pt ++ [Tr]);
pack_trans([], Pt) -> Pt.

%% out_actions(File, XrlFile, Deterministic, ActionList) -> ok.
%% Write out the action table.

out_actions(File, XrlFile, Deterministic, As) ->
    As1 = prep_out_actions(As),
    foreach(fun (A) -> out_action(File, A) end, As1),
    io:fwrite(File, "yyaction(_, _, _, _, _) -> error.~n", []),
    foreach(fun (A) -> out_action_code(File, XrlFile, Deterministic, A) end, As1).

prep_out_actions(As) ->
    map(fun ({A,empty_action}) ->
                {A,empty_action};
            ({A,Code,TokenChars,TokenLen,TokenLine,TokenCol,TokenLoc}) ->
                Vs = [{TokenChars,"TokenChars"},
                      {TokenLen,"TokenLen"},
                      {TokenLine or TokenLoc,"TokenLine"},
                      {TokenCol or TokenLoc,"TokenCol"},
                      {TokenChars,"YYtcs"},
                      {TokenLen or TokenChars,"TokenLen"}],
                Vars = [if F -> S; true -> "_" end || {F,S} <- Vs],
                Name = list_to_atom(lists:concat([yyaction_,A])),
                [Chars,Len,Line,Col,_,_] = Vars,
                Args = [V || V <- [Chars,Len,Line,Col], V =/= "_"],
                ArgsChars = lists:join(", ", Args),
                {A,Code,Vars,Name,Args,ArgsChars, TokenLoc}
        end, As).

out_action(File, {A,empty_action}) ->
    io:fwrite(File, "yyaction(~w, _, _, _, _) -> skip_token;~n", [A]);
out_action(File, {A,_Code,Vars,Name,_Args,ArgsChars,_TokenLoc}) ->
    [_,_,Line,Col,Tcs,Len] = Vars,
    io:fwrite(File, "yyaction(~w, ~s, ~s, ~s, ~s) ->~n", [A,Len,Tcs,Line,Col]),
    if
        Tcs =/= "_" ->
            io:fwrite(File, "    TokenChars = yypre(YYtcs, TokenLen),~n", []);
        true -> ok
    end,
    io:fwrite(File, "    ~s(~s);~n", [Name, ArgsChars]).

out_action_code(_File, _XrlFile, _Deterministic, {_A,empty_action}) ->
    ok;
out_action_code(File, XrlFile, Deterministic, {_A,Code,_Vars,Name,Args,ArgsChars, TokenLoc}) ->
    %% Should set the file to the .erl file, but instead assumes that
    %% ?LEEXINC is syntactically correct.
    io:fwrite(File, "\n-compile({inline,~w/~w}).\n", [Name, length(Args)]),
    L = erl_scan:line(hd(Code)),
    output_file_directive(File, XrlFile, Deterministic, L-2),
    io:fwrite(File, "~s(~s) ->~n", [Name, ArgsChars]),
    if
        TokenLoc -> io:fwrite(File,"    TokenLoc={TokenLine,TokenCol},~n",[]);
        true -> ok
    end,
    io:fwrite(File, "    ~ts\n", [pp_tokens(Code, L, File)]).

%% pp_tokens(Tokens, Line, File) -> [char()].
%%  Prints the tokens keeping the line breaks of the original code.

pp_tokens(Tokens, Line0, File) -> pp_tokens(Tokens, Line0, File, none).
    
pp_tokens([], _Line0, _, _) -> [];
pp_tokens([T | Ts], Line0, File, Prev) ->
    Line = erl_scan:line(T),
    [pp_sep(Line, Line0, Prev, T),
     pp_symbol(T, File) | pp_tokens(Ts, Line, File, T)].

pp_symbol({var,_,Var}, _) -> atom_to_list(Var);
pp_symbol({_,_,Symbol}, File) -> format_symbol(Symbol, File);
pp_symbol({dot, _}, _) -> ".";
pp_symbol({Symbol, _}, _) -> atom_to_list(Symbol).

pp_sep(Line, Line0, Prev, T) when Line > Line0 -> 
    ["\n    " | pp_sep(Line - 1, Line0, Prev, T)];
pp_sep(_, _, {'.',_}, _) -> "";        % No space after '.' (not a dot)
pp_sep(_, _, {'#',_}, _) -> "";        % No space after '#'
pp_sep(_, _, {'(',_}, _) -> "";        % No space after '('
pp_sep(_, _, {'[',_}, _) -> "";        % No space after '['
pp_sep(_, _, _, {'.',_}) -> "";        % No space before '.'
pp_sep(_, _, _, {'#',_}) -> "";        % No space before '#'
pp_sep(_, _, _, {',',_}) -> "";        % No space before ','
pp_sep(_, _, _, {')',_}) -> "";        % No space before ')'
pp_sep(_, _, _, _) -> " ".

%% out_dfa_graph(LeexState, DFA, DfaStart) -> ok | error.
%%  Writes the DFA to a .dot file in DOT-format which can be viewed
%%  with Graphviz.

out_dfa_graph(St, DFA, DF) ->
    verbose_print(St, "Writing DFA to file ~ts, ", [St#leex.gfile]),
    case file:open(St#leex.gfile, [write]) of
        {ok,Gfile} ->
            try
                %% Set the same encoding as infile:
                set_encoding(St, Gfile),
                io:fwrite(Gfile, "digraph DFA {~n", []),
                out_dfa_states(Gfile, DFA, DF),
                out_dfa_edges(Gfile, DFA),
                io:fwrite(Gfile, "}~n", []),
                verbose_print(St, "ok~n", []),
                St
            after ok = file:close(Gfile)
            end;
        {error,Error} ->
            verbose_print(St, "error~n", []),
            add_error({none,leex,{file_error,Error}}, St)
    end.

out_dfa_states(File, DFA, DF) ->
    foreach(fun (S) -> out_dfa_state(File, DF, S) end, DFA),
    io:fwrite(File, "~n", []).

out_dfa_state(File, DF, #dfa_state{no=DF, accept={accept,_}}) ->
    io:fwrite(File, "  ~b [shape=doublecircle color=green];~n", [DF]);
out_dfa_state(File, DF, #dfa_state{no=DF, accept=noaccept}) ->
    io:fwrite(File, "  ~b [shape=circle color=green];~n", [DF]);
out_dfa_state(File, _, #dfa_state{no=S, accept={accept,_}}) ->
    io:fwrite(File, "  ~b [shape=doublecircle];~n", [S]);    
out_dfa_state(File, _, #dfa_state{no=S, accept=noaccept}) ->
    io:fwrite(File, "  ~b [shape=circle];~n", [S]).

out_dfa_edges(File, DFA) ->
    foreach(fun (#dfa_state{no=S,trans=Trans}) ->
                    Pt = pack_trans(Trans),
                    Tdict = foldl(fun ({Cr,T}, D) ->
                                          orddict:append(T, Cr, D)
                                  end, orddict:new(), Pt),
                    foreach(fun (T) ->
                                    Crs = orddict:fetch(T, Tdict),
                                    Edgelab = dfa_edgelabel(Crs, File),
                                    io:fwrite(File, "  ~b -> ~b [label=\"~ts\"];~n",
                                              [S,T,Edgelab])
                            end, sort(orddict:fetch_keys(Tdict)))
            end, DFA).

dfa_edgelabel([C], File) when is_integer(C) -> quote(C, File);
dfa_edgelabel(Cranges, File) ->
    %% io:fwrite("el: ~p\n", [Cranges]),
    "[" ++ map(fun ({A,B}) -> [quote(A, File), "-", quote(B, File)];
                   (C)     -> [quote(C, File)]
               end, Cranges) ++ "]".

set_encoding(#leex{encoding = none}, File) ->
    ok = io:setopts(File, [{encoding, epp:default_encoding()}]);
set_encoding(#leex{encoding = E}, File) ->
    ok = io:setopts(File, [{encoding, E}]).

output_encoding_comment(_File, #leex{encoding = none}) ->
    ok;
output_encoding_comment(File, #leex{encoding = Encoding}) ->
    io:fwrite(File, <<"%% ~s\n">>, [epp:encoding_to_string(Encoding)]).

output_file_directive(File, Filename, Deterministic, Line) ->
    io:fwrite(File, <<"-file(~ts, ~w).\n">>,
              [format_filename(Filename, File, Deterministic), Line]).

format_filename(Filename0, File, Deterministic) ->
    Filename =
        case Deterministic of
            true ->
                filename:basename(filename:flatten(Filename0));
            false ->
                filename:flatten(Filename0)
        end,
    case enc(File) of
        unicode -> io_lib:write_string(Filename);
        latin1  -> io_lib:write_string_as_latin1(Filename)
    end.

format_symbol(Symbol, File) ->
    Format = case enc(File) of
                 latin1  -> "~p";
                 unicode -> "~tp"
             end,
    io_lib:fwrite(Format, [Symbol]).

enc(File) ->
    case lists:keyfind(encoding, 1, io:getopts(File)) of
	false -> latin1; % should never happen
	{encoding, Enc} -> Enc
    end.

quote($^, _File)  -> "\\^";
quote($., _File)  -> "\\.";
quote($$, _File)  -> "\\$";
quote($-, _File)  -> "\\-";
quote($[, _File)  -> "\\[";
quote($], _File)  -> "\\]";
quote($\s, _File) -> "\\\\s";
quote($\", _File) -> "\\\"";
quote($\b, _File) -> "\\\\b";
quote($\f, _File) -> "\\\\f";
quote($\n, _File) -> "\\\\n";
quote($\r, _File) -> "\\\\r";
quote($\t, _File) -> "\\\\t";
quote($\e, _File) -> "\\\\e";
quote($\v, _File) -> "\\\\v";
quote($\d, _File) -> "\\\\d";
quote($\\, _File) -> "\\\\";
quote(C, File) when is_integer(C) ->
    %% Must remove the $ and get the \'s right.
    S = case enc(File) of
            unicode -> io_lib:write_char(C);
            latin1  -> io_lib:write_char_as_latin1(C)
        end,
    case S of
        [$$,$\\|Cs] -> "\\\\" ++ Cs;
        [$$|Cs] -> Cs
    end;
quote(maxchar, _File) ->
    "MAXCHAR".
