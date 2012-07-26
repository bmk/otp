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

-module(http_socket_ip_comm).

-behaviour(http_socket).

-record(http_socket, {socket}).


%% --- start ---

start() ->
    case inet_db:start() of
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
    Opts = [binary, {packet, 0}, {active, false}, {reuseaddr, true} | Opts0],
    try 
	begin
	    mk_sock(gen_tcp:connect(Host, Port, Opts, Timeout))
	end
    catch 
        exit:{badarg, _} ->
            {error, {eoptions, Opts}};
	exit:badarg ->
            {error, {eoptions, Opts}}
    end.


%% --- listen ---

listen(Address, Port, IpFamilyDefault) ->
    listen(Address, Port, IpFamilyDefault, undefined).

listen(Address, Port, IpFamilyDefault, Fd) ->
    {NewPort, Opts, IpFamily} = 
	get_socket_info(Addr, Port, IpFamilyDefault, Fd),
    case IpFamily of
        inet6fb4 -> 
            Opts2 = [inet6 | Opts], 
            case (catch gen_tcp:listen(NewPort, Opts2)) of
                {error, Reason} when ((Reason =:= nxdomain) orelse 
                                      (Reason =:= eafnosupport) orelse 
				      (Reason =:= econnreset) orelse 
				      (Reason =:= enetunreach) orelse 
				      (Reason =:= econnrefused) orelse 
				      (Reason =:= ehostunreach)) ->
                    Opts3 = [inet | Opts], 
                    mk_sock(gen_tcp:listen(NewPort, Opts3));

                %% This is when a given hostname has resolved to a 
                %% IPv4-address. The inet6-option together with a 
                %% {ip, IPv4} option results in badarg
                {'EXIT', Reason} -> 
                    Opts3 = [inet | Opts], 
                    mk_sock(gen_tcp:listen(NewPort, Opts3)); 

                Other ->
                    Other
            end;
        _ ->
            Opts2 = [IpFamily | Opts],
            mk_sock(gen_tcp:listen(NewPort, Opts2))
    end.
    

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


mk_sock({ok, Socket}) ->
    {ok, #http_socket{socket = Socket}};
mk_sock(ERROR) ->
    ERROR.


