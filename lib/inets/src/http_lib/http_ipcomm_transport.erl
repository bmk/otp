%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2011. All Rights Reserved.
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

-module(http_ipcomm_transport).

-behaviour(httpc_transport).

%% API
-export([start/0, 
	 send/2, 
	 process_listen_info/5,
	 listen/3, 
	 connect/3, connect/4, 
	 setopts/2, 
	 getopts/1, getopts/2, 
	 getstat/1, 
	 close/1,
	 peername/1,
	 sockname/1,
	 negotiate/1, negotiate/2
	]).

%% Callback exports
-export([init/1,
	 handle_connect/5, 
	 handle_send/2, 
	 handle_setopts/2,
	 handle_getopts/2, 
	 handle_getstat/1, 
	 handle_close/1, 
	 handle_peername/1, 
	 handle_sockname/1, 
	 handle_negotiate/2]).

%% This is for future use...
-record(httpc_ipcomm_state, {}).


start() ->
    httpc_transport:start(?MODULE, []).


%% --- listen/3 ---

listen(TransportState, Addr, Port, MaybeFD) ->
    http_transport:listen(TransportState, Addr, Port, MaybeFD).


%% --- connect/3,4 ---

connect(TransportState, To, Opts) ->
    httpc_transport:connect(TransportState, To, Opts).

connect(TransportState, To, Opts, Timeout) ->
    httpc_transport:connect(TransportState, To, Opts, Timeout).


%% --- send/2 ---

send(Socket, Message) ->
    httpc_transport:send(Socket, Message).


%% --- send/2 ---

close(Socket) ->
    httpc_transport:close(Socket).


%% --- setopts/2 ---

setopts(Socket, Opts) ->
    httpc_transport:setopts(Socket, Opts).


%% --- getopts/1,2 ---

getopts(Socket) ->
    httpc_transport:getopts(Socket).

getopts(Socket, Opts) ->
    httpc_transport:getopts(Socket, Opts).


%% --- getopts/1,2 ---

getstat(Socket) ->
    httpc_transport:getstat(Socket).


%% --- peername/1 ---

peername(Socket) ->
    httpc_transport:peername(Socket).


%% --- peername/1 ---

sockname(Socket) ->
    httpc_transport:sockname(Socket).


%% --- negotiate/1,2 ---

negotiate(Socket) ->
    httpc_transport:negotiate(Socket).

negotiate(Socket, Timeout) ->
    httpc_transport:negotiate(Socket, Timeout).


%%----------------------------------------------------------------------
%% Callback API 
%%----------------------------------------------------------------------

init(_) ->
    case inet_db:start() of
	{ok, _} ->
	    {ok, #httpc_ipcomm_state{}};
	{error, {already_started, _}} ->
	    {ok, #httpc_ipcomm_state{}};
	Error ->
	    Error
    end.


handle_listen_args(_, Addr, Port, MaybeFD, BaseOpts, IpFamilyDefault) ->
    case get_fd(Port, MaybeFD, IpFamilyDefault) of
        {Fd, IpFamily} -> 
	    Opts = http_transport:listen_sock_opts(Addr, 
						   [{fd, Fd} | BaseOpts]), 
            {0, Opts, IpFamily};
        undefined ->
	    Opts = http_transport:listen_sock_opts(Addr, BaseOpts), 
            {Port, Opts, IpFamilyDefault}
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
    case (catch list_to_integer(FdStr)) of
        Fd when is_integer(Fd) ->
            Fd;
        _ ->
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



handle_connect(_, Host, Port, Opts0, Timeout) ->
    Opts = [binary, {packet, 0}, {active, false}, {reuseaddr, true} | Opts0],
    gen_tcp:connect(Host, Port, Opts, Timeout).


handle_close(Socket) ->
    gen_tcp:close(Socket).


handle_send(Socket, Message) ->
    gen_tcp:send(Socket, Message).


handle_setopts(Socket, Options) ->
    inet:setopts(Socket, Options).


handle_getopts(Socket, Options) ->
    inet:getopts(Socket, Options).


handle_getstat(Socket) ->
    inet:getstat(Socket).


handle_peername(Socket) ->
    inet:peername(Socket).


handle_sockname(Socket) ->
    inet:sockname(Socket).

handle_negotiate(_Socket, _Timeout) ->
    ok.


