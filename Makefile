
# distributed algorithms, n.dulay, 10 jan 22 
# coursework, raft 
# Makefile, v1

SERVERS   = 5      	
CLIENTS   = 5      	

TIMELIMIT = 15000	# quits after milli-seconds(ms)
SETUP     = very_unreliable_send	# one of default, slower, faster, etc

# AppendEntries(areq, arep, atim), Vote(vreq, vrep, vall), Election(etim), DB(dreq, drep), Client(creq, crep)
# Prefixes + for send/send_after,  - for receive
# DEBUG_OPTIONS = "!inf +areq -areq +arep -arep +vreq +vall -vreq +vrep -vrep +atim -atim +etim -etim +dreq -drep -creq -crep" # All Options Implemented
# DEBUG_OPTIONS = "!inf +vreq +vrep -etim" # Debug Elections election
# DEBUG_OPTIONS = "!inf -creq +crep +arep -areq" # Debug Client Requests
DEBUG_OPTIONS = "!inf" # Info Only
# DEBUG_OPTIONS = "none"

DEBUG_LEVEL   = 3

START     = Raft.start
HOST	 := 127.0.0.1

# --------------------------------------------------------------------

TIME    := $(shell date +%H:%M:%S)
SECS    := $(shell date +%S)
COOKIE  := $(shell echo $$PPID)

NODE_SUFFIX := ${SECS}_${LOGNAME}@${HOST}

ELIXIR  := elixir --no-halt --cookie ${COOKIE} --name
MIX 	:= -S mix run -e ${START} \
	${NODE_SUFFIX} ${TIMELIMIT} ${DEBUG_LEVEL} ${DEBUG_OPTIONS} \
	${SERVERS} ${CLIENTS} ${SETUP}

# --------------------------------------------------------------------

run cluster: compile
	@ echo -------------------------------------------------------------------
	@ ${ELIXIR} server1_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} server2_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} server3_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} server4_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} server5_${NODE_SUFFIX} ${MIX} cluster_wait &
	
	@ ${ELIXIR} client1_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} client2_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} client3_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} client4_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} client5_${NODE_SUFFIX} ${MIX} cluster_wait &
	@sleep 1
	@ ${ELIXIR} raft_${NODE_SUFFIX} ${MIX} cluster_start

compile:
	mix compile

clean:
	mix clean
	@rm -f erl_crash.dump

ps:
	@echo ------------------------------------------------------------
	epmd -names


