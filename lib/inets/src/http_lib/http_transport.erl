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

-module(http_transport).

-export([behaviour_info/1]).

-export([
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

-export([
	 which_transport/1, 
	 ipv4_name/1, 
	 ipv6_name/1, 
	 listen_sock_opts/2
	]).


-record(http_transport_state,  {mod, mod_state}).
-record(http_transport_socket, {mod, sock}).


%%%=========================================================================
%%%  API
%%%=========================================================================

behaviour_info(callbacks) ->
    [
     {init,        1},
     {listen,      3}, 
     {listen,      4}, 
     {listen_args, 6}, 
     {connect,     5}, 
     {close,       1}, 
     {send,        2}, 
     {setopts,     2}, 
     {getopts,     2}, 
     {getstat,     1}, 
     {peername,    1}, 
     {sockname,    1}, 
     {negotiate,   2} 
    ];
behaviour_info(_Other) ->
    undefined.


%%----------------------------------------------------------------------

start(Mod, Opts) ->
    try Mod:init(Opts) of
	{ok, ModState} ->
	    State = #http_transport_state{mod       = Mod, 
					  mod_state = ModState}, 
	    {ok, State};
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
    try Mod:connect(ModState, Host, Port, Opts, Timeout) of
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


listen(State, Addr, Port, MaybeFD) ->
    listen(State, Addr, Port, inet6fb4, MaybeFD).

listen(#httpc_transport_state{mod       = Mod, 
			      mod_state = ModState}, 
       Addr, Port, IpFamily0, MaybeFD) ->
    BaseOpts        = [{backlog, 128}, {reuseaddr, true}],
    try Mod:listen_args(Addr, Port, MaybeFD, BaseOpts, IpFamily0) of
	{NewPort, Opts, inet6fb4} when is_integer(NewPort) andalso 
				       (newPort >= 0) andalso 
				       is_lists(Opts) ->
	    %% We should try to use IPv6 first, 
	    %% and only if that fails, use IPv4
	    Opts2 = [inet6 | Opts], 
	    case (catch Mod:listen(ModState, NewPort, Opts2)) of
		{error, {no_ipv6_support, _} ->
		    Opts3 = [inet | Opts], 
		    Mod:listen(ModState, NewPort, Opts3);

		%% This is when a given hostname has resolved to a 
                %% IPv4-address. The inet6-option together with a 
                %% {ip, IPv4} option results in badarg
		{'EXIT', _} ->
		    Opts3 = [inet | Opts], 
		    Mod:listen(ModState, NewPort, Opts3);

		Other ->
		    Other
	    end;
	
	{NewPort, Opts, IpFamily} when is_integer(NewPort) andalso 
				       (newPort >= 0) andalso 
				       is_lists(Opts) ->
	    Opts2 = [IpFamily | Opts],
	    Mod:listen(ModState, NewPort, Opts2)
    catch
	throw:{error, Reason} ->
	    {error, Reason};
	T:E ->
	    {error, {T, E}}
    end.

send(#httpc_transport_socket{mod = Mod, sock = Socket}, Message) ->
    try
	begin
	    Mod:send(Socket, Message)
	end
    catch
	T:E ->
	    eoptions([Socket, Message], [T, E])
    end.
	


setopts(#httpc_transport_socket{mod = Mod, sock = Socket}, Options) ->
    try
	begin
	    Mod:setopts(Socket, Options)
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
	    Mod:getopts(Socket, Options)
	end
    catch
	T:E ->
	    eoptions(Options, [T, E])
    end.
	


getstat(#httpc_transport_socket{mod = Mod, sock = Socket}) ->
    try Mod:getstat(Socket) of
	{ok, Stats} ->
	    Stats;
	_ ->
	    []
    catch
	_:_ ->
	    []
    end.


close(#httpc_transport_socket{mod = Mod, sock = Socket}) ->
    (catch Mod:close(Socket)),
    ok.


peername(#httpc_transport_socket{mod = Mod, sock = Socket}) ->
    try Mod:peername(Socket) of
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
    try Mod:sockname(Socket) of
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
	    Mod:negotiate(Socket, Timeout)
	end
    catch
	T:E ->
	    eoptions([Socket, Timeout], [T, E]).
    end.

    

%%%========================================================================
%%% Behaviour utility functions
%%%========================================================================


which_transport(ip_comm) ->
    http_ipcomm_transport;
which_transport(_) ->
    http_ssl_transport.


%% -- sock_opts --
listen_sock_opts(undefined, Opts) -> 
    listen_sock_opts(Opts);
listen_sock_opts(any = Addr, Opts) -> 
    listen_sock_opts([{ip, Addr} | Opts]);
listen_sock_opts(Addr, Opts) ->
    listen_sock_opts([{ip, Addr} | Opts]).

listen_sock_opts(Opts) ->
    [{packet, 0}, {active, false} | Opts].



%%-------------------------------------------------------------------------
%% ipv4_name(Ipv4Addr) -> string()
%% ipv6_name(Ipv6Addr) -> string()
%%     Ipv4Addr = ip4_address()
%%     Ipv6Addr = ip6_address()
%%     
%% Description: Returns the local hostname. 
%%-------------------------------------------------------------------------
ipv4_name({A, B, C, D}) ->
    integer_to_list(A) ++ "." ++
        integer_to_list(B) ++ "." ++
        integer_to_list(C) ++ "." ++
        integer_to_list(D).

ipv6_name({A, B, C, D, E, F, G, H}) ->
    http_util:integer_to_hexlist(A) ++ ":"++ 
        http_util:integer_to_hexlist(B) ++ ":" ++  
        http_util:integer_to_hexlist(C) ++ ":" ++ 
        http_util:integer_to_hexlist(D) ++ ":" ++  
        http_util:integer_to_hexlist(E) ++ ":" ++  
        http_util:integer_to_hexlist(F) ++ ":" ++  
        http_util:integer_to_hexlist(G) ++ ":" ++  
        http_util:integer_to_hexlist(H).


%%%========================================================================
%%% Internal functions
%%%========================================================================

eoptions(Opts) ->
    eoptions(Opts, []).
eoptions(Opts, Extra) ->
    {error, {eoptions, Opts, Extra}}.

