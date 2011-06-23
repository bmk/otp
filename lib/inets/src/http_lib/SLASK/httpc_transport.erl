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

-module(httpc_transport).

-export([behaviour_info/1]).

-export([
	 which_transport/1, 
	 start/2, 
	 connect/3, connect/4, 
	 send/2,
	 setopts/2, 
	 getopts/1, getopts/2, 
	 getstat/1,
	 close/1,
	 peername/1,
	 sockname/1,
	 negotiate/2
	]).


-record(httpc_transport_state,  {mod, mod_state}).
-record(httpc_transport_socket, {mod, sock}).


%%%=========================================================================
%%%  API
%%%=========================================================================

behaviour_info(callbacks) ->
    [
     {init,             1},
     {handle_connect,   5}, 
     {handle_close,     1}, 
     {handle_send,      2}, 
     {handle_setopts,   2}, 
     {handle_getopts,   2}, 
     {handle_getstat,   1}, 
     {handle_peername,  1}, 
     {handle_sockname,  1}, 
     {handle_negotiate, 2} 
    ];
behaviour_info(_Other) ->
    undefined.


%%----------------------------------------------------------------------

which_transport(ip_comm) ->
    httpc_ipcomm_transport;
which_transport(_) ->
    httpc_ssl_transport.


start(Mod, Opts) ->
    try Mod:init(Opts) of
	{ok, ModState} ->
	    #httpc_transport_state{mod       = Mod, 
				   mod_state = ModState};
	Error ->
	    Error
    catch
	T:E ->
	    {error, {T, E}}
    end.


connect(State, To, Opts) ->
    connect(State, To, Opts, infinity).

connect(#httpc_transport_state{mod       = Mod, 
			       mod_state = ModState}, 
	{Host, Port}, Opts, Timeout) ->
    try Mod:handle_connect(ModState, Host, Port, Opts, Timeout) of
	{ok, Socket} ->
	    {ok, #httpc_transport_socket{mod = Mod, sock = Socket}};
	{error, _} = ERROR ->
	    ERROR
    catch
        exit:{badarg, _} ->
            eoptions([Host, Port, Opts, Timeout]);
	exit:badarg ->
            eoptions([Host, Port, Opts, Timeout]);
	T:E ->
	    eoptions([Host, Port, Opts, Timeout], [T, E])
    
    end.


send(#httpc_transport_socket{mod = Mod, sock = Socket}, Message) ->
    try
	begin
	    Mod:handle_send(Socket, Message)
	end
    catch
	T:E ->
	    eoptions([Socket, Message], [T, E])
    end.
	


setopts(#httpc_transport_socket{mod = Mod, sock = Socket}, Options) ->
    try
	begin
	    Mod:handle_setopts(Socket, Options)
	end
    catch
	T:E ->
	    eoptions(Options, [T, E])
    end.


getopts(Socket) ->
    Options = [packet, 
	       packet_size, 
	       recbuf, 
	       sndbuf, 
	       priority, 
	       tos, 
	       send_timeout],
    getopts(Socket, Options).

getopts(#httpc_transport_socket{mod = Mod, sock = Socket}, Options) ->
    try 
	begin
	    Mod:handle_getopts(Socket, Options)
	end
    catch
	T:E ->
	    eoptions(Options, [T, E])
    end.
	


getstat(#httpc_transport_socket{mod = Mod, sock = Socket}) ->
    try Mod:handle_getstat(Socket) of
	{ok, Stats} ->
	    Stats;
	_ ->
	    []
    catch
	_:_ ->
	    []
    end.


close(#httpc_transport_socket{mod = Mod, sock = Socket}) ->
    (catch Mod:handle_close(Socket)),
    ok.


peername(#httpc_transport_socket{mod = Mod, sock = Socket}) ->
    try Mod:handle_peername(Socket) of
	{ok, {Addr, Port}} when is_tuple(Addr) andalso (size(Addr) =:= 4) ->
            PeerName = ipv4_name(Addr), 
            {Port, PeerName};
        {ok, {Addr, Port}} when is_tuple(Addr) andalso (size(Addr) =:= 8) ->
            PeerName = ipv6_name(Addr), 
            {Port, PeerName};
        {error, _} ->
            {-1, "unknown"}
    catch
	T:E ->
	    eoptions([Socket], [T, E])
    end.

	
sockname(#httpc_transport_socket{mod = Mod, sock = Socket}) ->
    try Mod:handle_sockname(Socket) of
	{ok, {Addr, Port}} when is_tuple(Addr) andalso (size(Addr) =:= 4) ->
            PeerName = ipv4_name(Addr), 
            {Port, PeerName};
        {ok, {Addr, Port}} when is_tuple(Addr) andalso (size(Addr) =:= 8) ->
            PeerName = ipv6_name(Addr), 
            {Port, PeerName};
        {error, _} ->
            {-1, "unknown"}
    catch
	T:E ->
	    eoptions([Socket], [T, E])
    end.


negotiate(#httpc_transport_socket{mod = Mod, sock = Socket}, Timeout) ->
    try
	begin
	    Mod:handle_negotiate(Socket, Timeout)
	end
    catch
	T:E ->
	    eoptions([Socket, Timeout], [T, E]).
    end.

    
eoptions(Opts) ->
    eoptions(Opts, []).
eoptions(Opts, Extra) ->
    {error, {eoptions, Opts, Extra}}.

ipv4_name(Addr) -> http_transport:ipv4_name(Addr).
ipv6_name(Addr) -> http_transport:ipv6_name(Addr).
