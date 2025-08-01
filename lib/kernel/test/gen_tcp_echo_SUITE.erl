%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 1997-2025. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%
-module(gen_tcp_echo_SUITE).

-include_lib("common_test/include/ct.hrl").
-include("kernel_test_lib.hrl").

%%-compile(export_all).

-export([all/0, suite/0,groups/0,init_per_suite/1, end_per_suite/1, 
	 init_per_group/2,end_per_group/2, 
	 init_per_testcase/2, end_per_testcase/2,
	 active_echo/1, passive_echo/1, active_once_echo/1,
	 slow_active_echo/1, slow_passive_echo/1,
	 limit_active_echo/1, limit_passive_echo/1,
	 large_limit_active_echo/1, large_limit_passive_echo/1]).

-define(TPKT_VRSN, 3).
-define(LINE_LENGTH, 1023). % (default value of gen_tcp option 'recbuf') - 1

suite() ->
    [{ct_hooks, [ts_install_cth]},
     {timetrap, {minutes,1}}].

all() ->
    case ?TEST_INET_BACKENDS() of
        true ->
            [
             {group, inet_backend_default},
             {group, inet_backend_inet},
             {group, inet_backend_socket}
            ];
        _ ->
            [
             {group, inet_backend_default}
            ]
    end.

groups() ->
    [{inet_backend_default, [{group, read_ahead}, {group, no_read_ahead}]},
     {inet_backend_socket,  [{group, read_ahead}, {group, no_read_ahead}]},
     {inet_backend_inet,    [{group, read_ahead}, {group, no_read_ahead}]},
     %%
     {read_ahead,       [{group, no_delay_send}, {group, delay_send}]},
     {no_read_ahead,    [{group, no_delay_send}, {group, delay_send}]},
     %%
     {no_delay_send,    testcases()},
     {delay_send,       testcases()}].

testcases() ->
    [active_echo, passive_echo, active_once_echo,
     slow_active_echo, slow_passive_echo, limit_active_echo,
     limit_passive_echo, large_limit_active_echo,
     large_limit_passive_echo].


init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.


init_per_group(inet_backend_default = _GroupName, Config) ->
    ?P("~w(~w) -> check explicit inet-backend when"
       "~n   Config: ~p", [?FUNCTION_NAME, _GroupName, Config]),
    case ?EXPLICIT_INET_BACKEND(Config) of
        undefined ->
            [{socket_create_opts, []} | Config];
        inet ->
            {skip, "explicit inet-backend = inet"};
        socket ->
            {skip, "explicit inet-backend = socket"}
    end;
init_per_group(inet_backend_inet = _GroupName, Config) ->
    ?P("~w(~w) -> check explicit inet-backend when"
       "~n   Config: ~p", [?FUNCTION_NAME, _GroupName, Config]),
    case ?EXPLICIT_INET_BACKEND(Config) of
        undefined ->
            case ?EXPLICIT_INET_BACKEND() of
                true ->
                    %% The environment trumps us,
                    %% so only the default group should be run!
                    {skip, "explicit inet backend"};
                false ->
                    [{socket_create_opts, [{inet_backend, inet}]} | Config]
            end;
        inet ->
            [{socket_create_opts, [{inet_backend, inet}]} | Config];
        socket ->
            {skip, "explicit inet-backend = socket"}
    end;
init_per_group(inet_backend_socket = _GroupName, Config) ->
    ?P("~w(~w) -> check explicit inet-backend when"
       "~n   Config: ~p", [?FUNCTION_NAME, _GroupName, Config]),
    case ?EXPLICIT_INET_BACKEND(Config) of
        undefined ->
            case ?EXPLICIT_INET_BACKEND() of
                true ->
                    %% The environment trumps us,
                    %% so only the default group should be run!
                    {skip, "explicit inet backend"};
                false ->
                    [{socket_create_opts, [{inet_backend, socket}]} | Config]
            end;
        inet ->
            {skip, "explicit inet-backend = inet"};
        socket ->
            [{socket_create_opts, [{inet_backend, socket}]} | Config]
    end;
init_per_group(Name, Config) ->
    case Name of
        no_read_ahead -> [{read_ahead, false} | Config];
        delay_send    -> [{delay_send, true}  | Config];
        _ -> Config
    end.

%% init_per_group_inet_backend(Backend, Config) ->
%%     case kernel_test_lib:explicit_inet_backend() of
%%         true ->
%%             %% Contradicting kernel variables - skip group
%%             {skip, "explicit inet backend"};
%%         false ->
%%             kernel_test_lib:config_inet_backend(Config, Backend)
%%     end.

end_per_group(Name, Config) ->
    case Name of
        no_read_ahead   -> lists:keydelete(read_ahead, 1, Config);
        delay_send      -> lists:keydelete(delay_send, 1, Config);
        _ -> Config
    end.


init_per_testcase(Name, Config) ->
    _ =
        case Name of
            slow_active_echo    -> ct:timetrap({minutes, 5});
            slow_passive_echo   -> ct:timetrap({minutes, 5});
            _ -> ok
        end,
    Config.

end_per_testcase(_Name, _Config) ->
    ok.


sockopts(Config) ->
    [Option ||
        {Name, _} = Option <- Config,
        lists:member(Name, [read_ahead, delay_send])].


%% Test sending packets of various sizes and various packet types
%% to the echo port and receiving them again (socket in active mode).
active_echo(Config) when is_list(Config) ->
    echo_test(Config, [], fun active_echo/4, [{echo, fun echo_server/0}]).

%% Test sending packets of various sizes and various packet types
%% to the echo port and receiving them again (socket in passive mode).
passive_echo(Config) when is_list(Config) ->
    echo_test(
      Config, [{active, false}], fun passive_echo/4,
      [{echo, fun echo_server/0}]).

%% Test sending packets of various sizes and various packet types
%% to the echo port and receiving them again (socket in active once mode).
active_once_echo(Config) when is_list(Config) ->
    echo_test(
      Config, [{active, once}], fun active_once_echo/4,
      [{echo, fun echo_server/0}]).

%% Test sending packets of various sizes and various packet types
%% to the echo port and receiving them again (socket in active mode).
%% The echo server is a special one that delays between every character.
slow_active_echo(Config) when is_list(Config) ->
    echo_test(
      Config, [], fun active_echo/4,
      [slow_echo, {echo, fun slow_echo_server/0}]).

%% Test sending packets of various sizes and various packet types
%% to an echo server and receiving them again (socket in passive mode).
%% The echo server is a special one that delays between every character.
slow_passive_echo(Config) when is_list(Config) ->
    echo_test(
      Config, [{active, false}], fun passive_echo/4,
      [slow_echo, {echo, fun slow_echo_server/0}]).

%% Test sending packets of various sizes and various packet types
%% to the echo port and receiving them again (socket in active mode)
%% with packet_size limitation.
limit_active_echo(Config) when is_list(Config) ->
    echo_test(
      Config, [{packet_size, 10}], fun active_echo/4,
      [{packet_size, 10}, {echo, fun echo_server/0}]).

%% Test sending packets of various sizes and various packet types
%% to the echo port and receiving them again (socket in passive mode)
%% with packet_size limitation.
limit_passive_echo(Config) when is_list(Config) ->
    echo_test(
      Config, [{packet_size, 10},{active, false}], fun passive_echo/4,
      [{packet_size, 10}, {echo, fun echo_server/0}]).

%% Test sending packets of various sizes and various packet types
%% to the echo port and receiving them again (socket in active mode)
%% with large packet_size limitation.
large_limit_active_echo(Config) when is_list(Config) ->
    echo_test(
      Config, [{packet_size, 10}], fun active_echo/4,
      [{packet_size, (1 bsl 32)-1}, {echo, fun echo_server/0}]).

%% Test sending packets of various sizes and various packet types
%% to the echo port and receiving them again (socket in passive mode)
%% with large packet_size limitation.
large_limit_passive_echo(Config) when is_list(Config) ->
    echo_test(
      Config, [{packet_size, 10},{active, false}], fun passive_echo/4,
      [{packet_size, (1 bsl 32) -1}, {echo, fun echo_server/0}]).

echo_test(Config, SockOpts_0, EchoFun, EchoOpts_0) ->
    SockOpts = SockOpts_0 ++ sockopts(Config),
    ct:log("SockOpts = ~p.", [SockOpts]),
    EchoSrvFun = proplists:get_value(echo, EchoOpts_0),
    {ok, EchoPort} = EchoSrvFun(),
    EchoOpts = [{echo_port, EchoPort}|EchoOpts_0],

    echo_packet(Config, [{packet, 1}|SockOpts], EchoFun, EchoOpts),
    echo_packet(Config, [{packet, 2}|SockOpts], EchoFun, EchoOpts),
    echo_packet(Config, [{packet, 4}|SockOpts], EchoFun, EchoOpts),
    echo_packet(Config, [{packet, sunrm}|SockOpts], EchoFun, EchoOpts),
    echo_packet(Config, [{packet, cdr}|SockOpts], EchoFun,
		[{type, {cdr, big}}|EchoOpts]),
    echo_packet(Config, [{packet, cdr}|SockOpts], EchoFun,
		[{type, {cdr, little}}|EchoOpts]),
    case lists:keymember(packet_size, 1, SockOpts) of
	false ->
	    %% This is cheating, we should test that packet_size
	    %% also works for line and http.
	    echo_packet(
              Config, [{packet, line}|SockOpts], EchoFun, EchoOpts),
	    echo_packet(
              Config, [{packet, http}|SockOpts], EchoFun, EchoOpts),
	    echo_packet(
              Config, [{packet, http_bin}|SockOpts], EchoFun, EchoOpts);

	true -> ok
    end,
    echo_packet(Config, [{packet, tpkt}|SockOpts], EchoFun, EchoOpts),

    ShortTag = [16#E0],
    LongTag = [16#1F, 16#83, 16#27],
    echo_packet(Config, [{packet, asn1}|SockOpts], EchoFun,
		[{type, {asn1, short, ShortTag}}|EchoOpts]),
    echo_packet(Config, [{packet, asn1}|SockOpts], EchoFun,
		[{type, {asn1, long, ShortTag}}|EchoOpts]),
    echo_packet(Config, [{packet, asn1}|SockOpts], EchoFun,
		[{type, {asn1, short, LongTag}}|EchoOpts]),
    echo_packet(Config, [{packet, asn1}|SockOpts], EchoFun,
		[{type, {asn1, long, LongTag}}|EchoOpts]),
    ok.

echo_packet(Config, SockOpts, EchoFun, EchoOpts) ->
    Type = case lists:keyfind(type, 1, EchoOpts) of
	       {_, T} ->
		   T;
	       false ->
		   {_, T} = lists:keyfind(packet, 1, SockOpts),
		   T
	   end,

    %% Connect to the echo server.
    EchoPort = proplists:get_value(echo_port, EchoOpts),
    {ok, Echo} =
        kernel_test_lib:connect(Config, localhost, EchoPort, SockOpts),

    ct:pal("Echo socket: ~w", [Echo]),

    SlowEcho = lists:member(slow_echo, EchoOpts),

    case Type of
	http ->
	    echo_packet_http(Echo, Type, EchoFun);
	http_bin ->
	    echo_packet_http(Echo, Type, EchoFun);
	_ ->
	    echo_packet0(Echo, Type, EchoFun, SlowEcho, EchoOpts)
    end.

echo_packet_http(Echo, Type, EchoFun) ->
    lists:foreach(fun(Uri)-> P1 = http_request(Uri),
			     EchoFun(Echo, Type, P1, http_reply(P1, Type))
		  end,
		  http_uri_variants()),
    P2 = http_response(),
    EchoFun(Echo, Type, P2, http_reply(P2, Type)).

echo_packet0(Echo, Type, EchoFun, SlowEcho, EchoOpts) ->
    PacketSize =
	case lists:keyfind(packet_size, 1, EchoOpts) of
	    {_,Sz} when Sz < 10 -> Sz;
	    {_,_} -> 10;
	    false -> 0
	end,
    ct:log("echo_packet0[~w] ~p", [self(), PacketSize]),
    %% Echo small packets first.
    echo_packet1(Echo, Type, EchoFun, 0),
    echo_packet1(Echo, Type, EchoFun, 1),
    echo_packet1(Echo, Type, EchoFun, 2),
    echo_packet1(Echo, Type, EchoFun, 3),
    echo_packet1(Echo, Type, EchoFun, 4),
    echo_packet1(Echo, Type, EchoFun, 7),
    if PacketSize =/= 0 ->
	    echo_packet1(Echo, Type, EchoFun,
			 {PacketSize-1, PacketSize}),
	    echo_packet1(Echo, Type, EchoFun,
			 {PacketSize, PacketSize}),
	    echo_packet1(Echo, Type, EchoFun,
			 {PacketSize+1, PacketSize});
       not SlowEcho -> % Go on with bigger packets if not slow echo server.
	    echo_packet1(Echo, Type, EchoFun, 10),
	    echo_packet1(Echo, Type, EchoFun, 13),
	    echo_packet1(Echo, Type, EchoFun, 126),
	    echo_packet1(Echo, Type, EchoFun, 127),
	    echo_packet1(Echo, Type, EchoFun, 128),
	    echo_packet1(Echo, Type, EchoFun, 255),
	    echo_packet1(Echo, Type, EchoFun, 256),
	    echo_packet1(Echo, Type, EchoFun, 1023),
	    echo_packet1(Echo, Type, EchoFun, 3747),
	    echo_packet1(Echo, Type, EchoFun, 32767),
	    echo_packet1(Echo, Type, EchoFun, 32768),
	    echo_packet1(Echo, Type, EchoFun, 65531),
	    echo_packet1(Echo, Type, EchoFun, 65535),
	    echo_packet1(Echo, Type, EchoFun, 65536),
	    echo_packet1(Echo, Type, EchoFun, 70000),
	    echo_packet1(Echo, Type, EchoFun, infinite);
       true -> ok
    end,
    PacketSize =:= 0 andalso
        begin
            %% Switch to raw mode and echo one byte 
            ok = inet:setopts(Echo, [{packet, raw}, {active, false}]),
            ok = gen_tcp:send(Echo, <<"$">>),
            case gen_tcp:recv(Echo, 1) of
                {ok, <<"$">>} -> ok;
                {ok, "$"} -> ok
            end
        end,
    _CloseResult = gen_tcp:close(Echo),
    ct:log("echo_packet0[~w] close: ~p", [self(), _CloseResult]),
    ok.

echo_packet1(EchoSock, Type, EchoFun, Size) ->
    case packet(Size, Type) of
	false ->
	    ok;
	Packet ->
	    ct:log("Type ~p, size ~p, time ~p",
		      [Type, Size, time()]),
	    case EchoFun(EchoSock, Type, Packet, [Packet]) of
		ok ->
		    case Size of
			{N, Max} when N > Max ->
			    ct:fail(
			      {packet_through, {N, Max}});
			_ -> ok
		    end;
		{error, emsgsize} ->
		    case Size of
			{N, Max} when N > Max ->
			    ct:log(" Blocked!");
			_ ->
			    ct:fail(
			      {packet_blocked, Size})
		    end;
		Error ->
		    ct:fail(Error)
	    end
    end.

active_echo(Sock, Type, Packet, PacketEchos) ->
    ok = gen_tcp:send(Sock, Packet),
    active_recv(Sock, Type, PacketEchos).

active_recv(_, _, []) ->
    ok;
active_recv(Sock, Type, [PacketEcho|Tail]) ->
    Tag = case Type of 
	      http -> http;
	      http_bin -> http;
	      _ -> tcp
	  end,
    receive Recv->Recv end,
    %%ct:log("Active received: ~p\n",[Recv]),
    case Recv of
	{Tag, Sock, PacketEcho} ->
	    active_recv(Sock, Type, Tail);
	{Tag, Sock, Bad} ->
            ct:log("Packet: ~p", [inet:getopts(Sock, [packet])]),
	    ct:fail({wrong_data, Bad, PacketEcho});
	{tcp_error, Sock, Reason} ->
	    {error, Reason};
	Other ->
            ct:log("Packet: ~p", [inet:getopts(Sock, [packet])]),
	    ct:fail({unexpected_message, Other, {Tag, Sock, PacketEcho}})
    end.

passive_echo(Sock, _Type, Packet, PacketEchos) ->
    ok = gen_tcp:send(Sock, Packet),
    passive_recv(Sock, PacketEchos).

passive_recv(_, []) ->
    ok;
passive_recv(Sock, [PacketEcho | Tail]) ->
    Recv = gen_tcp:recv(Sock, 0),
    %%ct:log("Passive received: ~p\n",[Recv]),
    case Recv of
	{ok, PacketEcho} ->
	    passive_recv(Sock, Tail);
	{ok, Bad} ->
	    ct:log("Expected: ~p\nGot: ~p\n",[PacketEcho,Bad]),
	    ct:fail({wrong_data, Bad, PacketEcho});
	{error,PacketEcho} ->
	    passive_recv(Sock, Tail); % expected error
	{error, _}=Error ->
	    Error;
	Other ->
	    ct:fail({unexpected_message, Other})
    end.

active_once_echo(Sock, Type, Packet, PacketEchos) ->
    ok = gen_tcp:send(Sock, Packet),
    active_once_recv(Sock, Type, PacketEchos).

active_once_recv(_, _, []) ->
    ok;
active_once_recv(Sock, Type, [PacketEcho | Tail]) ->
    Tag = case Type of
	      http -> http;
	      http_bin -> http;
	      _ -> tcp
	  end,
    receive
	{Tag, Sock, PacketEcho} ->
	    inet:setopts(Sock, [{active, once}]),
	    active_once_recv(Sock, Type, Tail);
	{Tag, Sock, Bad} ->
            ct:log("Packet: ~p", [inet:getopts(Sock, [packet])]),
	    ct:fail({wrong_data, Bad, PacketEcho});
	{tcp_error, Sock, Reason} ->
	    {error, Reason};
	Other ->
            ct:log("Packet: ~p", [inet:getopts(Sock, [packet])]),
	    ct:fail({unexpected_message, Other, {Tag, Sock, PacketEcho}})
    end.

%%% Building of random packets.

packet(infinite, {asn1, _, Tag}) ->
    Tag++[16#80];
packet(infinite, _) ->
    false;
packet({Size, _RecvLimit}, Type) ->
    packet(Size, Type);
packet(Size, 1) when Size > 255 ->
    false;
packet(Size, 2) when Size > 65535 ->
    false;
packet(Size, {asn1, _, Tag}) when Size < 128 ->
    Tag++[Size|random_packet(Size)];
packet(Size, {asn1, short, Tag}) when Size < 256 ->
    Tag++[16#81, Size|random_packet(Size)];
packet(Size, {asn1, short, Tag}) when Size < 65536 ->
    Tag++[16#82|put_int16(Size, big, random_packet(Size))];
packet(Size, {asn1, _, Tag}) ->
    Tag++[16#84|put_int32(Size, big, random_packet(Size))];
packet(Size, {cdr, Endian}) ->
    [$G, $I, $O, $P,				% magic
     1, 0,					% major minor
     if Endian == big -> 0; true -> 1 end,	% flags: byte order
     0 |					% message type
     put_int32(Size, Endian, random_packet(Size))];
packet(Size, sunrm) ->
    put_int32(Size, big, random_packet(Size));
packet(Size, line) when Size > ?LINE_LENGTH ->
    false;
packet(Size, line) ->
    random_packet(Size, "\n");
packet(Size, tpkt) ->
    HeaderSize = 4,
    PacketSize = HeaderSize + Size,
    if PacketSize < 65536 ->
	    Header = [?TPKT_VRSN, 0 | put_int16(PacketSize, big)],
	    HeaderSize = length(Header), % Just to assert cirkular dependency
	    Header ++ random_packet(Size);
       true ->
	    false
    end;
packet(Size, _Type) ->
    random_packet(Size).



random_packet(Size) ->
    random_packet(Size, "", random_char()).

random_packet(Size, Tail) ->
    random_packet(Size, Tail, random_char()).

random_packet(0, Result, _NextChar) ->
    Result;
random_packet(Left, Result, NextChar0) ->
    NextChar =
	if
	    NextChar0 >= 126 ->
		33;
	    true ->
		NextChar0+1
	end,
    random_packet(Left-1, [NextChar0|Result], NextChar).

random_char() ->
    random_char("abcdefghijklmnopqrstuvxyzABCDEFGHIJKLMNOPQRSTUVXYZ0123456789").

random_char(Chars) ->
    lists:nth(uniform(length(Chars)), Chars).

uniform(N) ->
    rand:uniform(N).

put_int32(X, big, List) ->
    [ (X bsr 24) band 16#ff, 
      (X bsr 16) band 16#ff,
      (X bsr 8) band 16#ff,
      (X) band 16#ff | List ];
put_int32(X, little, List) ->
    [ (X) band 16#ff,
      (X bsr 8) band 16#ff,
      (X bsr 16) band 16#ff,
      (X bsr 24) band 16#ff | List].

put_int16(X, ByteOrder) ->
    put_int16(X, ByteOrder, []).

put_int16(X, big, List) ->
    [ (X bsr 8) band 16#ff,
      (X) band 16#ff | List ];
put_int16(X, little, List) ->
    [ (X) band 16#ff,
      (X bsr 8) band 16#ff | List ].

%%% A normal echo server, for systems that don't have one.

echo_server() ->
    Self = self(),
    spawn_link(fun() -> echo_server(Self) end),
    receive
	{echo_port, Port} ->
	    {ok, Port}
    end.

echo_server(ReplyTo) ->
    {ok, S} = gen_tcp:listen(0, [{active, false}, binary]),
    {ok, {_, Port}} = inet:sockname(S),
    ReplyTo ! {echo_port, Port},
    echo_server_loop(S).

echo_server_loop(Sock) ->
    {ok, E} = gen_tcp:accept(Sock),
    Self = self(),
    spawn_link(fun() -> echoer(E, Self) end),
    echo_server_loop(Sock).

echoer(Sock, Parent) ->
    unlink(Parent),
    echoer_loop(Sock).

echoer_loop(Sock) ->
    case gen_tcp:recv(Sock, 0) of
	{ok, Data} ->
	    ok = gen_tcp:send(Sock, Data),
	    echoer_loop(Sock);
	{error, closed} ->
	    ok
    end.

%%% A "slow" echo server, which will echo data with a short delay
%%% between each character.

slow_echo_server() ->
    Self = self(),
    spawn_link(fun() -> slow_echo_server(Self) end),
    receive
	{echo_port, Port} ->
	    {ok, Port}
    end.

slow_echo_server(ReplyTo) ->
    {ok, S} = gen_tcp:listen(0, [{active, false}, {nodelay, true}]),
    {ok, {_, Port}} = inet:sockname(S),
    ReplyTo ! {echo_port, Port},
    slow_echo_server_loop(S).

slow_echo_server_loop(Sock) ->
    {ok, E} = gen_tcp:accept(Sock),
    spawn_link(fun() -> slow_echoer(E, self()) end),
    slow_echo_server_loop(Sock).

slow_echoer(Sock, Parent) ->
    unlink(Parent),
    slow_echoer_loop(Sock).

slow_echoer_loop(Sock) ->
    case gen_tcp:recv(Sock, 0) of
	{ok, Data} ->
	    slow_send(Sock, Data),
	    slow_echoer_loop(Sock);
	{error, closed} ->
	    ok
    end.

slow_send(Sock, [C|Rest]) ->
    ok = gen_tcp:send(Sock, [C]),
    receive after 1 ->
		    slow_send(Sock, Rest)
	    end;
slow_send(_, []) ->
    ok.

http_request(Uri) ->
    list_to_binary(["POST ", Uri, <<" HTTP/1.1\r\n"
				    "Connection: close\r\n"
				    "Host: localhost:8000\r\n"
				    "User-Agent: perl post\r\n"
				    "Content-Length: 4\r\n"
				    "Content-Type: text/xml; charset=utf-8\r\n"
				    "Other-Field: with some text\r\n"
				    "Multi-Line: Once upon a time in a land far far away,\r\n"
				    " there lived a princess imprisoned in the highest tower\r\n"
				    " of the most haunted castle.\r\n"
				    "Invalid line without a colon\r\n"
				    "\r\n">>]).

http_uri_variants() ->
    ["*",
     "http://tools.ietf.org/html/rfcX3986",
     "http://otp.ericsson.se:8000/product/internal/",
     "https://example.com:8042/over/there?name=ferret#nose",
     "ftp://cnn.example.com&story=breaking_news@10.0.0.1/top_story.htm",
     "/some/absolute/path",
     "something_else", "something_else"].

http_response() ->
    <<"HTTP/1.0 404 Object Not Found\r\n"
      "Server: inets/4.7.16\r\n"
      "Date: Fri, 04 Jul 2008 17:16:22 GMT\r\n"
      "Content-Type: text/html\r\n"
      "Content-Length: 207\r\n"
      "\r\n">>.

http_reply(Bin, Type) ->
    {ok, Line, Rest} = erlang:decode_packet(Type,Bin,[]),
    HType = case Type of
		http -> httph;
		http_bin -> httph_bin
	    end,
    Ret = lists:reverse(http_reply(Rest,[Line],HType)),
    ct:log("HTTP: ~p\n",[Ret]),
    Ret.

http_reply(<<>>, Acc, _) ->
    Acc;
http_reply(Bin, Acc, HType) ->
    {ok, Line, Rest} = erlang:decode_packet(HType,Bin,[]),	
    http_reply(Rest, [Line | Acc], HType).
