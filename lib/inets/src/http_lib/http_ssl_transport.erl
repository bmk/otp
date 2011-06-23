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

-module(http_ssl_transport).

-behaviour(httpc_transport).

%% API
-export([start/1, 
	 send/2, 
	 connect/3, connect/4, 
	 setopts/2, 
	 getopts/1, getopts/2, 
	 getstat/1, 
	 close/1,
	 peername/1,
	 sockname/1,
	 negotiate/1, negotiate/2]).

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

-record(httpc_ssl_state, {config = []}).


start(SslConfig) ->
    httpc_transport:start(?MODULE, [SslConfig]).


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

init([SslConfig]) ->
    case ssl:start() of
        ok ->
	    {ok, #httpc_ssl_state{config = SslConfig}};
	{error, {already_started,_}} ->
	    {ok, #httpc_ssl_state{config = SslConfig}};
	Error ->
	    Error
    end.


handle_listen_args(#http_ssl_state{config = SslConfig}, 
		   Addr, Port, _MaybeFD, BaseOpts, IpFamilyDefault) ->
    Opts = http_transport:listen_sock_opts(Addr, BaseOpts ++ SslConfig), 
    {Port, Opts, IpFamilyDefault}.


handle_listen(_, Port, Opts) ->
    case ssl:listen(Port, Opts) of
	{ok, _} = OK ->
	    OK;
	{error, Reason} ->
	    case lists:member(Reason, [nxdomain, eafnosupport]) of
		true ->
		    %% No IPv6 support
		    {error, {no_ipv6_support, Reason}};
		false ->
		    {error, Reason}
	    end
    end.


handle_connect(#httpc_ssl_state{config = SslConfig}, 
	       Host, Port, Opts0, Timeout) ->
    Opts = [binary, {active, false}, {ssl_imp, new} | Opts0] ++ SslConfig,
    ssl:connect(Host, Port, Opts, Timeout).


handle_close(Socket) ->
    ssl:close(Socket).


handle_send(Socket, Message) ->
    ssl:send(Socket, Message).


handle_setopts(Socket, Options) ->
    ssl:setopts(Socket, Options).


handle_getopts(Socket, Options) ->
    ssl:getopts(Socket, Options).


handle_getstat(_Socket) ->
    [].


handle_peername(Socket) ->
    ssl:peername(Socket).


handle_sockname(Socket) ->
    ssl:sockname(Socket).


handle_negotiate(Socket, Timeout) ->
    case ssl:ssl_accept(Socket, Timeout) of
        ok ->
            ok;
        {error, Reason} ->
            %% Look for "valid" error reasons
            ValidReasons = [timeout, econnreset, esslaccept, esslerrssl], 
            case lists:member(Reason, ValidReasons) of
                true ->
                    {error, normal};
                false ->
                    {error, Reason}
	    end
    end.


