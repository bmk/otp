%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2005-2025. All Rights Reserved.
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
%%----------------------------------------------------------------------
%% Purpose: Erlang record definitions for each named and unnamed
%%          SEQUENCE and SET in module MEDIA-GATEWAY-CONTROL
%%----------------------------------------------------------------------

-record('MegacoMessage',
	{
	  authHeader = asn1_NOVALUE,
	  mess
	 }).

-record('AuthenticationHeader',
	{
	  secParmIndex, 
	  seqNum, 
	  ad
	 }).

-record('Message',
	{
	  version, 
	  mId, 
	  messageBody
	 }). % with extension mark

-record('DomainName',
	{
	  name, 
	  portNumber = asn1_NOVALUE
	 }).

-record('IP4Address',
	{
	  address,
	  portNumber = asn1_NOVALUE
	 }).

-record('IP6Address',
	{
	  address, 
	  portNumber = asn1_NOVALUE
	 }).


%% Transaction ::= CHOICE
%% {
%% 	transactionRequest		TransactionRequest,
%% 	transactionPending		TransactionPending,
%% 	transactionReply		TransactionReply,
%% 	transactionResponseAck		TransactionResponseAck,
%% 	-- use of response acks is dependent on underlying transport
%% 	...,
%% 	segmentReply			SegmentReply
%% }

-record('TransactionRequest',
	{
	  transactionId, 
	  actions = []
	 }). % with extension mark

-record('TransactionPending',
	{
	  transactionId
	 }). % with extension mark

-record('TransactionReply',
	{
	  transactionId, 
	  immAckRequired = asn1_NOVALUE, 
	  transactionResult,

	  %% with extension mark -- v3 --

	  segmentNumber        = asn1_NOVALUE,
	  segmentationComplete = asn1_NOVALUE
	 }). 


%% -- v3 --
-record('SegmentReply', 
	{
	  transactionId, 
	  segmentNumber, 
	  segmentationComplete = asn1_NOVALUE
	 }). % with extension mark

%% SegmentNumber ::= INTEGER(0..65535)

-record('TransactionAck',
	{
	  firstAck, 
	  lastAck = asn1_NOVALUE
	 }).

-record('ErrorDescriptor',
	{
	  errorCode, 
	  errorText = asn1_NOVALUE
	 }).

-record('ActionRequest',
	{
	  contextId, 
	  contextRequest = asn1_NOVALUE, 
	  contextAttrAuditReq = asn1_NOVALUE, 
	  commandRequests = []
	 }).

-record('ActionReply',
	{
	  contextId, 
	  errorDescriptor = asn1_NOVALUE, 
	  contextReply = asn1_NOVALUE, 
	  commandReply = []
	 }).

-record('ContextRequest',
	{
	  priority = asn1_NOVALUE, 
	  emergency = asn1_NOVALUE, 
	  topologyReq = asn1_NOVALUE,

	  %% with extension mark -- prev3b --

	  iepscallind = asn1_NOVALUE,
	  contextProp = asn1_NOVALUE,

	  %% -- prev3c --

	  contextList = asn1_NOVALUE

	 }). 

-record('ContextAttrAuditRequest',
	{
	  topology = asn1_NOVALUE, 
	  emergency = asn1_NOVALUE, 
	  priority = asn1_NOVALUE,

	  %% with extension mark -- prev3b --

	  iepscallind = asn1_NOVALUE,
	  contextPropAud = asn1_NOVALUE,

	  %% -- prev3c --

	  selectpriority = asn1_NOVALUE,
	  selectemergency = asn1_NOVALUE,
	  selectiepscallind = asn1_NOVALUE,
	  selectLogic = asn1_NOVALUE
	 }). 


%% SelectLogic            ::= CHOICE
%% {
%%     andAUDITSelect  NULL,     -- all selection conditions satisfied
%%     orAUDITSelect   NULL,     -- at least one selection condition satisfied
%%     ...
%% }

-record('CommandRequest',
	{
	  command, 
	  optional = asn1_NOVALUE, 
	  wildcardReturn = asn1_NOVALUE
	 }). % with extension mark

-record('TopologyRequest',
	{
	  terminationFrom, 
	  terminationTo, 
	  topologyDirection,
	  
	  %% After extension mark
	  streamID = asn1_NOVALUE,  

	  %% -- prev3c --
	  %% This is actually not according to the standard,
	  %% but without it 'TopologyRequest' will be useless.
	  topologyDirectionExtension = asn1_NOVALUE
	  
	 }).

-record('AmmRequest',
	{
	  terminationID = [], 
	  descriptors = []
	 }). % with extension mark

-record('AmmsReply',
	{
	  terminationID = [], 
	  terminationAudit = asn1_NOVALUE
	 }). % with extension mark

-record('SubtractRequest',
	{
	  terminationID = [], 
	  auditDescriptor = asn1_NOVALUE
	 }). % with extension mark

-record('AuditRequest',
	{
	  terminationID, 
	  auditDescriptor,

	  %% -- prev3c (after extension mark) --  

	  terminationIDList = asn1_NOVALUE

	 }). 

%% AuditReply := CHOICE
%% {
%%    contextAuditResult   TerminationIDList,
%%    error                ErrorDescriptor,
%%    auditResult          AuditResult,
%%    ...
%%    auditResultTermList  TermListAuditResult
%% }

-record('AuditResult',
	{
	  terminationID, 
	  terminationAuditResult = []
	 }).

-record('TermListAuditResult', 
	{
	  terminationIDList,
	  terminationAuditResult = []
	 }). % with extension mark

-record('AuditDescriptor',
	{
	  auditToken         = asn1_NOVALUE,
	  %% with extensions
	  auditPropertyToken = asn1_NOVALUE  
	 }). 


%% --- v2 start ---

-record('IndAudMediaDescriptor',
	{
	  termStateDescr = asn1_NOVALUE,
	  streams        = asn1_NOVALUE
	}). % with extension mark

-record('IndAudStreamDescriptor',
	{
	  streamID,
	  streamParms
	}). % with extension mark

-record('IndAudStreamParms',
	{
	  localControlDescriptor = asn1_NOVALUE,
	  localDescriptor        = asn1_NOVALUE, %% NOTE: NOT IN TEXT
	  remoteDescriptor       = asn1_NOVALUE, %% NOTE: NOT IN TEXT
	  
	  %% with extension mark -- prev3b --

	  statisticsDescriptor   = asn1_NOVALUE
	}). 

-record('IndAudLocalControlDescriptor',
	{
	  streamMode    = asn1_NOVALUE,
	  reserveValue  = asn1_NOVALUE,
	  reserveGroup  = asn1_NOVALUE,
	  propertyParms = asn1_NOVALUE,

	  %% -- prev3c (after extension mark) --

	  streamModeSel = asn1_NOVALUE

	}). 

-record('IndAudPropertyParm',
	{
	  name,

	  %% -- prev3c (after extension mark) --

	  propertyParms = asn1_NOVALUE
	}). 

-record('IndAudLocalRemoteDescriptor',
	{
	  propGroupID = asn1_NOVALUE,
	  propGrps
	}). % with extension mark

%% IndAudPropertyGroup ::= SEQUENCE OF IndAudPropertyParm


%% BUGBUG
%% In text, it can only be one of them in each record.
%% So, in case it's eventBufferControl or serviceState
%% propertyParms will be an empty list.
-record('IndAudTerminationStateDescriptor',
	{
	  propertyParms = [],  %% Optional in text...
	  eventBufferControl = asn1_NOVALUE,
	  serviceState       = asn1_NOVALUE,

	  %% -- prev3c (after extension mark) --

	  serviceStateSel    = asn1_NOVALUE

	}). 

-record('IndAudEventsDescriptor',
	{
	  requestID = asn1_NOVALUE,  %% Only optional in ASN.1
	  pkgdName,
	  streamID  = asn1_NOVALUE
	}). % with extension mark

-record('IndAudEventBufferDescriptor',
	{
	  eventName,
	  %% This is an ugly hack to allow the eventParameterName
	  %% which only exist in text!! 
	  %% streamID = asn1_NOVALUE | integer() | 
	  %%            {eventParameterName, Name}  <- BUGBUG: ONLY IN TEXT
	  %% Note that the binary codecs will fail to encode
	  %% if the streamID is not aither asn1_NOVALUE or an integer()
	  %% So it is recommended to refrain from using this text feature...
	  streamID = asn1_NOVALUE

	  %% eventParameterName = asn1_NOVALUE %% BUGBUG: ONLY IN TEXT

	}). % with extension mark

-record('IndAudSeqSigList',
	{
	  id,
	  signalList  = asn1_NOVALUE  %% Only in ASN1
	}). % with extension mark

-record('IndAudSignal',
	{
	  signalName,
	  streamID = asn1_NOVALUE, % Optional in ASN1 & non-existent in text

	  %% -- prev3c (after extension mark) --

	  signalRequestID = asn1_NOVALUE

	}). % with extension mark

-record('IndAudDigitMapDescriptor',
	{
	  digitMapName = asn1_NOVALUE  %% OPTIONAL in ASN.1 but not in text
	}). 

-record('IndAudStatisticsDescriptor',
	{
	  statName
	}). 

-record('IndAudPackagesDescriptor',
	{
	  packageName,
	  packageVersion
	}). % with extension mark


%% --- v2 end   ---


-record('NotifyRequest',
	{
	  terminationID = [], 
	  observedEventsDescriptor, 
	  errorDescriptor = asn1_NOVALUE
	 }). % with extension mark

-record('NotifyReply',
	{
	  terminationID   = [], 
	  errorDescriptor = asn1_NOVALUE
	 }). % with extension mark

-record('ObservedEventsDescriptor',
	{
	  requestId, 
	  observedEventLst = []
	 }).

-record('ObservedEvent',
	{
	  eventName, 
	  streamID = asn1_NOVALUE, 
	  eventParList = [], 
	  timeNotation = asn1_NOVALUE
	 }). % with extension mark

%% This value field of this record is already encoded and will
%% be inserted as is.
%% This record could be used either when there is a bug in the
%% encoder or if an "external" package, unknown to the megaco app,
%% where the value part requires a special encode.
-record(megaco_event_parameter,
	{
	  name, 
	  value
	 }). 

-record('EventParameter',
	{
	  eventParameterName, 
	  value,
	  extraInfo = asn1_NOVALUE
	 }). % with extension mark

-record('ServiceChangeRequest',
	{
	  terminationID = [], 
	  serviceChangeParms
	 }). % with extension mark

-record('ServiceChangeReply',
	{
	  terminationID = [], 
	  serviceChangeResult = []
	 }). % with extension mark

-record('TerminationID',
	{
	  wildcard, 
	  id
	 }). % with extension mark

%% TerminationIDList ::= SEQUENCE OF TerminationID 

-record('MediaDescriptor',
	{
	  termStateDescr = asn1_NOVALUE, 
	  streams        = asn1_NOVALUE
	 }). % with extension mark

-record('StreamDescriptor',
	{
	  streamID, 
	  streamParms
	 }).

-record('StreamParms',
	{
	  localControlDescriptor = asn1_NOVALUE, 
	  localDescriptor = asn1_NOVALUE, 
	  remoteDescriptor = asn1_NOVALUE,
	  
	  %% with extension mark -- prev3b --

	  statisticsDescriptor   = asn1_NOVALUE
	 }). 

-record('LocalControlDescriptor',
	{
	  streamMode   = asn1_NOVALUE, 
	  reserveValue = asn1_NOVALUE, 
	  reserveGroup = asn1_NOVALUE, 
	  propertyParms = []
	 }). % with extension mark

%% StreamMode ::= ENUMERATED
%% {
%%   sendOnly(0),
%%   recvOnly(1),
%%   sendRecv(2),
%%   inactive(3),
%%   loopBack(4),
%%   ...
%% }

-record('PropertyParm',
	{
	  name, 
	  value, 
	  extraInfo = asn1_NOVALUE
	 }). % with extension mark

-record('LocalRemoteDescriptor',
	{
	  propGrps = []
	 }). % with extension mark

-record('TerminationStateDescriptor',
	{
	  propertyParms = [], 
	  eventBufferControl = asn1_NOVALUE, 
	  serviceState = asn1_NOVALUE
	 }). % with extension mark

%% EventBufferControl ::= ENUMERATED
%% {
%%   off(0),
%%   lockStep(1),
%%   ...
%% }

%% ServiceState ::= ENUMERATED
%% {
%%   test(0),
%%   outOfSvc(1),
%%   inSvc(2),
%%   ...
%% }

-record('MuxDescriptor',
	{
	  muxType, 
	  termList = [],
	  nonStandardData = asn1_NOVALUE
	 }). % with extension mark

-record('EventsDescriptor',
	{
	  requestID,
	  %% BUGBUG: IG 6.82 was withdrawn
	  %% requestID = asn1_NOVALUE, 
	  eventList = []
	 }). % with extension mark

-record('RequestedEvent',
	{
	  pkgdName, 
	  streamID = asn1_NOVALUE, 
	  eventAction = asn1_NOVALUE, 
	  evParList = []
	 }). % with extension mark

%% -- prev3c --
-record('RegulatedEmbeddedDescriptor', 
	{
	  secondEvent       = asn1_NOVALUE, 
	  signalsDescriptor = asn1_NOVALUE
	 }). % with extension mark

%% NotifyBehaviour ::= CHOICE
%% {
%%    notifyImmediate  NULL,
%%    notifyRegulated  RegulatedEmbeddedDescriptor,
%%    neverNotify      NULL,
%%    ...
%% }

-record('RequestedActions',
	{
	  keepActive = asn1_NOVALUE, 
	  eventDM = asn1_NOVALUE, 
	  secondEvent = asn1_NOVALUE, 
	  signalsDescriptor = asn1_NOVALUE,

	  %% -- prev3c (after extension mark) --

	  notifyBehaviour       = asn1_NOVALUE, 
	  resetEventsDescriptor = asn1_NOVALUE

	 }). 

-record('SecondEventsDescriptor',
	{
	  requestID, 
	  %% BUGBUG: IG 6.82 was withdrawn
	  %% requestID = asn1_NOVALUE, 
	  eventList = []
	 }). % with extension mark

-record('SecondRequestedEvent',
	{
	  pkgdName, 
	  streamID = asn1_NOVALUE, 
	  eventAction = asn1_NOVALUE, 
	  evParList = []
	 }). % with extension mark

-record('SecondRequestedActions',
	{
	  keepActive = asn1_NOVALUE, 
	  eventDM = asn1_NOVALUE, 
	  signalsDescriptor = asn1_NOVALUE,

	  %% -- prev3c (after extension mark) --

	  notifyBehaviour       = asn1_NOVALUE, 
	  resetEventsDescriptor = asn1_NOVALUE

	 }). 


%% EventBufferDescriptor ::= SEQUENCE OF EventSpec 

-record('EventSpec',
	{
	  eventName, 
	  streamID = asn1_NOVALUE, 
	  eventParList = []
	 }). % with extension mark


%% SignalsDescriptor ::= SEQUENCE OF SignalRequest 

%% SignalRequest ::= CHOICE 
%%  { 
%%    signal         Signal, 
%%    seqSigList     SeqSigList, 
%%    ... 
%%  } 


-record('SeqSigList',
	{
	  id, 
	  signalList = []
	 }).

-record('Signal',
	{
	  signalName, 
	  streamID = asn1_NOVALUE, 
	  sigType = asn1_NOVALUE, 
	  duration = asn1_NOVALUE, 
	  notifyCompletion = asn1_NOVALUE, 
	  keepActive = asn1_NOVALUE, 
	  sigParList = [],

	  %% with extension mark -- prev3b --

	  direction = asn1_NOVALUE,
	  requestID = asn1_NOVALUE,

	  %% -- prev3c --

	  intersigDelay = asn1_NOVALUE

	 }). 

%% SignalType ::= ENUMERATED 
%%  { 
%%    brief(0), 
%%    onOff(1), 
%%    timeOut(2), 
%%    ... 
%%  } 

%% SignalDirection ::= ENUMERATED
%%  {
%%    internal(0),
%%    external(1),
%%    both(3),
%%    ...
%%  }

%% SignalName ::= PkgdName 

%% NotifyCompletion ::= BIT STRING 
%%  { 
%%    onTimeOut(0), onInterruptByEvent(1), 
%%    onInterruptByNewSignalDescr(2), otherReason(3), onIteration(4)
%%  } 

-record('SigParameter',
	{
	  sigParameterName, 
	  value,
	  extraInfo = asn1_NOVALUE
	 }). % with extension mark

-record('ModemDescriptor',
	{
	  mtl, 
	  mpl,
	  nonStandardData = asn1_NOVALUE
	 }).

-record('DigitMapDescriptor',
	{
	  digitMapName = asn1_NOVALUE, 
	  digitMapValue = asn1_NOVALUE
	 }).

-record('DigitMapValue',
	{
	  startTimer = asn1_NOVALUE, 
	  shortTimer = asn1_NOVALUE, 
	  longTimer = asn1_NOVALUE, 
	  digitMapBody,
	  %% with extensions
	  durationTimer = asn1_NOVALUE
	 }). 

-record('ServiceChangeParm',
	{
	  serviceChangeMethod, 
	  serviceChangeAddress = asn1_NOVALUE, 
	  serviceChangeVersion = asn1_NOVALUE, 
	  serviceChangeProfile = asn1_NOVALUE, 
	  serviceChangeReason, 
	  serviceChangeDelay = asn1_NOVALUE, 
	  serviceChangeMgcId = asn1_NOVALUE, 
	  timeStamp = asn1_NOVALUE,
	  nonStandardData = asn1_NOVALUE,

	  %% with extension mark -- prev3b (serviceChangeIncompleteFlag) --

	  serviceChangeInfo = asn1_NOVALUE,
	  serviceChangeIncompleteFlag = asn1_NOVALUE
	 }). 

-record('ServiceChangeResParm',
	{
	  serviceChangeMgcId = asn1_NOVALUE, 
	  serviceChangeAddress = asn1_NOVALUE, 
	  serviceChangeVersion = asn1_NOVALUE, 
	  serviceChangeProfile = asn1_NOVALUE,
	  timeStamp = asn1_NOVALUE
	 }). % with extension mark


%% This is the actual ASN.1 type and it is as this it will
%% be represented if the encoding config [native] is chosen.
%% %% String of at least 1 character and at most 67 characters (ASN.1). 
%% %% 64 characters for name, 1 for "/", 2 for version to match ABNF
%% -record('ServiceChangeProfile',
%% 	{
%% 	  profileName
%% 	 }
%%        ).

-record('ServiceChangeProfile',
	{
	  profileName, 
	  version
	 }).


-record('PackagesItem',
	{
	  packageName, 
	  packageVersion
	 }). % with extension mark

-record('StatisticsParameter',
	{
	  statName, 
	  statValue = asn1_NOVALUE
	 }).

-record('TimeNotation',
	{
	  date, 
	  time
	 }).

