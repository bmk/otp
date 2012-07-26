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

-module(http_socket).


-export([
	 resolve/0, 
	 a2n/1, n2a/1
	]).

-export_type([
	      connect_timeout/0, 
	      accept_timeout/0, 
	      negotiate_timeout/0, 
	      fd/0, 
	      ip_family/0
	     ]).

-type connect_timeout() :: infinity | non_neg_integer(). 
-type accept_timeout()  :: infinity | non_neg_integer(). 
-type fd()              :: non_neg_integer(). 
-type ip_family()       :: inet | inet6 | inet6fb4.



%%% ----------------------------------------------------------------------
%%% 
%%%         Define the  *** H T T P   S O C K E T *** behaviour
%%% 
%%% ----------------------------------------------------------------------

%% --- start ---

-callback start() ->
    ok | {error, Reason :: term()}.


%% --- connect ---

-callback connect(Address :: inet:ip_address(), 
		  Port    :: inet:port_number(), 
		  Opts    :: list()) ->
    {ok, Socket :: term()} | {error, Reason :: term()}.

-callback connect(Address :: inet:ip_address(), 
		  Port    :: inet:port_number(), 
		  Opts    :: list(), 
		  Timeout :: infinity | connect_timeout()) ->
    {ok, Socket :: term()} | {error, Reason :: term()}.


%% --- listen ---

-callback listen(Address         :: inet:ip_address(), 
		 Port            :: inet:port_number(), 
		 IpFamilyDefault :: ip_family()) ->


-callback listen(Address         :: inet:ip_address(), 
		 Port            :: inet:port_number(), 
		 IpFamilyDefault :: ip_family(), 
		 Fd              :: fd()) ->
    {ok, Socket :: term()} | {error, Reason :: term()}.


%% --- accept ---

-callback accept(ListenSocket :: term()) ->
    {ok, Socket :: term()} | {error, Reason :: term()}.

-callback accept(ListenSocket :: term(), 
		 Timeout      :: accept_timeout()) ->
    {ok, Socket :: term()} | {error, Reason :: term()}.


%% --- close ---

-callback close(Socket :: term()) ->
    ok | {error, Reason :: term()}.


%% --- send ---

-callback send(Socket  :: term(), 
	       Message :: inet:iodata()) ->
    ok | {error, Reason :: term()}.


%% --- controlling_process ---

-callback controlling_process(Socket   :: term(), 
			      NewOwner :: pid()) ->
    ok | {error, Reason :: term()}.


%% --- setopts ---

-callback setopts(Socket :: term(), 
		  Opts   :: list()) ->
    ok | {error, Reason :: term()}.


%% --- getopts ---

-callback setopts(Socket :: term()) ->
    {ok, OptValues :: list()} | {error, Reason :: term()}.

-callback setopts(Socket :: term(), 
		  Opts   :: list()) ->
    {ok, OptValues :: list()} | {error, Reason :: term()}.


%% --- getstats ---

-callback getstats(Socket :: term()) ->
    {ok, Stats :: list()} | {error, Reason :: term()}.


%% --- peername ---

-callback peername(Socket :: term()) ->
    {ok, PeerName :: string(), Port :: inet:port_number()} | 
    {error, Reason :: term()}.


%% --- sockname ---

-callback sockname(Socket :: term()) ->
    {ok, SockName :: string(), Port :: inet:port_number()} | 
    {error, Reason :: term()}.


%% --- negotiate ---

-callback negotiate(Socket  :: term(), 
		    Timeout :: negotiate_timeout()) ->
    ok | {error, Reason :: term()}.



%%% ----------------------------------------------------------------------
%%% 
%%%         Utility functions 
%%% 
%%% ----------------------------------------------------------------------


--spec resolve() ->
    Hostname :: string().

resolve() ->
    {ok, Name} = inet:gethostname(),
    Name.


%% --- sock_opts --- 

-spec sock_opts(Address :: undefined | any | inet:ip_address(), 
		Opts    :: list()) ->
    NewOpts :: list().
		
sock_opts(undefined, Opts) -> 
    sock_opts(Opts);
sock_opts(any = Addr, Opts) -> 
    sock_opts([{ip, Addr} | Opts]);
sock_opts(Addr, Opts) ->
    sock_opts([{ip, Addr} | Opts]).

sock_opts(Opts) ->
    [{packet, 0}, {active, false} | Opts].




%% --- a2n --- 
%% Transform an address: "A.B.C.D" -> {A,B,C,D} 

-spec a2n(AS :: string()) ->
    AT :: inet:ip_address().

a2n(AS) -> inet_parse:address(AS).


%% --- a2n --- 
%% Transform an address: {A,B,C,D} -> "A.B.C.D"

-spec a2n(AT :: inet:ip_address()) ->
    AS :: string().

n2a(AT) -> inet_parse:ntoa(AT).

