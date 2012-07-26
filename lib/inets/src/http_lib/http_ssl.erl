%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2012-2012. All Rights Reserved.
%%
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% %CopyrightEnd%
%%

-module(http_socket_ssl).

-behaviour(http_socket).

-record(http_socket, {socket, config}).


%% --- start ---

start() ->
    case ssl:start() of
        {ok, _} ->
            ok;
        {error, {already_started, _}} ->
            ok;
        Error ->
            Error
    end.
    

%% --- connect ---

connect(Address, Port, Opts) ->
    connect(Address, Port, Opts, infinity).

connect(Address, Port, Opts0, Timeout) ->
    {Config, Opts1} = extract_config(Opts0), 
    Opts = [binary, {active, false} | Opts1] ++ Config,
    try 
	begin
	    mk_sock(ssl:connect(Host, Port, Opts, Timeout), Config)
	end
    catch 
	_:_ ->
            {error, {eoptions, Opts}}
    end.

extract_config(Opts) ->
    case lists:keysearch(ssl_config, 1, Opts) of
	{value, {_, Config}} ->
	    Opts2 = lists:keydelete(ssl_config, 1, Opts),
	    {Config, Opts2};
	false ->
	    {[], Opts}
    end.


%% --- listen ---

listen(Address, Port, IpFamilyDefault) ->
    Opts = [{ssl_imp, new}, {reuseaddr, true} | SSLConfig]


    listen(Address, Port, IpFamilyDefault, undefined).

listen(Address, Port, IpFamilyDefault, _Fd) ->
    listen(Address, Port, IpFamilyDefault.
    

get_socket_info(Addr, Port, IpFamilyDefault, Fd0) ->
    BaseOpts = [{backlog, 128}, {reuseaddr, true}], 
    %% The presence of a file descriptor takes precedence
    case get_fd(Port, Fd0, IpFamilyDefault) of
        {Fd, IpFamily} -> 
            {0, http_socket:sock_opts(Addr, [{fd, Fd} | BaseOpts]), IpFamily};
        undefined ->
            {Port, http_socket:sock_opts(Addr, BaseOpts), IpFamilyDefault}
    end.

get_fd(Port, undefined = _Fd, IpFamilyDefault) ->
    FdKey = list_to_atom("httpd_" ++ integer_to_list(Port)),
    case init:get_argument(FdKey) of
        {ok, [[Value]]} ->
            case string:tokens(Value, [$|]) of
                [FdStr, IpFamilyStr] ->
                    {fd_of(FdStr), ip_family_of(IpFamilyStr)};
                [FdStr] ->
                    {fd_of(FdStr), IpFamilyDefault};
                _ ->
                    throw({error, {bad_descriptor, Value}})
            end;
        error ->
            undefined
    end;
get_fd(_Port, Fd, IpFamilyDefault) ->
    {Fd, IpFamilyDefault}.

fd_of(FdStr) ->
    try 
	begin
	    list_to_integer(FdStr)
	end
    catch
	error:badarg ->
            throw({error, {bad_descriptor, FdStr}})
    end.

ip_family_of(IpFamilyStr) ->
    IpFamily = list_to_atom(IpFamilyStr),
    case lists:member(IpFamily, [inet, inet6, inet6fb4]) of
        true ->
            IpFamily;
        false ->
            throw({error, {bad_ipfamily, IpFamilyStr}})
    end.


%% --- accept ---

accept(ListenSocket) ->
    accept(ListenSocket, infinity).

accept(#http_socket{socket = ListenSocket}, Timeout) ->
    gen_tcp:accept(ListenSocket, Timeout).


%% --- close ---

close(#http_socket{socket = Socket}) ->
    gen_tcp:close(Socket).


%% --- send ---

send(#http_socket{socket = Socket}, Message) ->
    gen_tcp:send(Socket, Message).


%% --- controlling_process ---

controlling_process(#http_socket{socket = Socket}, NewOwner) ->
    gen_tcp:controlling_process(Socket, NewOwner). 


%% --- setopts ---

setopts(#http_socket{socket = Socket}, Options) ->
    inet:setopts(Socket, Options). 


%% --- getopts ---

getopts(Socket) ->
    Opts = [packet, packet_size, recbuf, sndbuf, priority, tos, send_timeout], 
    getopts(SocketType, Socket, Opts).

getopts(#http_socket{socket = Socket}, Options) ->
    case inet:getopts(Socket, Opts) of
	{ok, SocketOpts} ->
	    SocketOpts;
	_ ->
	    []
    end.


%% --- getstats ---

getstat(#http_socket{socket = Socket}) ->
    case inet:getstat(Socket) of
        {ok, Stats} ->
            Stats;
        _ ->
            []
    end. 


%% --- peername ---

peername(#http_socket{socket = Socket}) ->
    case inet:peername(Socket) of
	{ok, {Address, Port}} ->
	    {ok, http_socket:n2a(Address), Port};
	ERROR ->
	    ERROR
    end.


%% --- coekname ---

sockname(#http_socket{socket = Socket}) ->
    case inet:sockname(Socket) of
	{ok, {Address, Port}} ->
	    {ok, http_socket:n2a(Address), Port};
	ERROR ->
	    ERROR
    end.


%% --- negotiate ---

negotiate(_, _) ->
    ok.


%%% ----------------------------------------------------------------------
%%%         Internal functions 
%%% ----------------------------------------------------------------------


mk_sock({ok, Socket}, Config) ->
    {ok, #http_socket{socket = Socket, config = Config}};
mk_sock(ERROR, _) ->
    ERROR.


