#!/usr/bin/env bash

APPNAME="exportbenchmark"
COUNT=10000

# find voltdb binaries in either installation or distribution directory.
if [ -n "$(which voltdb 2> /dev/null)" ]; then
    VOLTDB_BIN=$(dirname "$(which voltdb)")
else
    VOLTDB_BIN="$(dirname $(dirname $(dirname $(pwd))))/bin"
    echo "The VoltDB scripts are not in your PATH."
    echo "For ease of use, add the VoltDB bin directory: "
    echo
    echo $VOLTDB_BIN
    echo
    echo "to your PATH."
    echo
fi

# call script to set up paths, including
# java classpaths and binary paths
source $VOLTDB_BIN/voltenv

VOLTDB="$VOLTDB_BIN/voltdb"
LOG4J="$VOLTDB_VOLTDB/log4j.xml"
LICENSE="$VOLTDB_VOLTDB/license.xml"
HOST="localhost"

# remove build artifacts
function clean() {
    rm -rf obj debugoutput $APPNAME.jar voltdbroot statement-plans catalog-report.html log "$VOLTDB_LIB/ExportBenchmark.jar"
}

function clean() {
    rm -rf voltdbroot log obj *.log *.jar
}

# Grab the necessary command line arguments
function parse_command_line() {
    OPTIND=1

    while getopts ":h?e:n:" opt; do
	case "$opt" in
	e)
	    ARG=$( echo $OPTARG | tr "," "\n" )
	    for e in $ARG; do
		EXPORTS+=("$e")
	    done
	    ;;
	n)
	    COUNT=$OPTARG
	    ;;
	esac
    done

    # Return the function to run
    shift $(($OPTIND - 1))
    RUN=$@
}

function build_deployment_file() {
    exit
}

# compile the source code for procedures and the client into jarfiles
function srccompile() {
    javac -classpath $APPCLASSPATH procedures/exportbenchmark/*.java
    javac -classpath $CLIENTCLASSPATH client/exportbenchmark/ExportBenchmark.java
    # stop if compilation fails
    if [ $? != 0 ]; then exit; fi
    jar cf ExportBenchmark.jar -C procedures exportbenchmark
    jar cf exportbenchmark-client.jar -C client exportbenchmark
    rm -rf client/exportbenchmark/*.class procedures/exportbenchmark/*.class
}

function jars() {
     srccompile-ifneeded
}

# compile the procedure and client jarfiles if they don't exist
function srccompile-ifneeded() {
    if [ ! -e ExportBenchmark.jar ] || [ ! -e exportbenchmark-client.jar ]; then
        srccompile;
    fi
}

# run the voltdb server locally
function server() {
    voltdb init --force
    FR_TEMP=/tmp/${USER}/fr
    mkdir -p ${FR_TEMP}
    # Set up flight recorder options
    VOLTDB_OPTS="-XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseTLAB"
    VOLTDB_OPTS="${VOLTDB_OPTS} -XX:CMSInitiatingOccupancyFraction=75 -XX:+UseCMSInitiatingOccupancyOnly"
    # VOLTDB_OPTS="${VOLTDB_OPTS} -XX:+UnlockCommercialFeatures -XX:+FlightRecorder"
    # VOLTDB_OPTS="${VOLTDB_OPTS} -XX:FlightRecorderOptions=maxage=1d,defaultrecording=true,disk=true,repository=${FR_TEMP},threadbuffersize=128k,globalbuffersize=32m"
    # VOLTDB_OPTS="${VOLTDB_OPTS} -XX:StartFlightRecording=name=${APPNAME}"
    # truncate the voltdb log
    [[ -d log && -w log ]] && > log/volt.log
    # run the server
    echo "Starting the VoltDB server."
    echo "To perform this action manually, use the command line: "
    echo
    echo "VOLTDB_OPTS=\"${VOLTDB_OPTS}\" ${VOLTDB} start -H $HOST -l ${LICENSE}"
    echo
    #VOLTDB_OPTS="${VOLTDB_OPTS}" ${VOLTDB} create -d deployment.xml -l ${LICENSE} -H ${HOST} ${APPNAME}.jar
    VOLTDB_OPTS="${VOLTDB_OPTS}" ${VOLTDB} start -H $HOST -l ${LICENSE}
}

# load schema and procedures
function init() {
    srccompile-ifneeded
    sqlcmd < exportTable.sql
}

# run the client that drives the example
function client() {
    run_benchmark
}

function run_benchmark_help() {
    srccompile-ifneeded
    java -classpath exportbenchmark-client.jar:$CLIENTCLASSPATH exportbenchmark.ExportBenchmark --help
}

function run_benchmark() {
    srccompile-ifneeded
    java -classpath exportbenchmark-client.jar:$CLIENTCLASSPATH -Dlog4j.configuration=file://$LOG4J \
        exportbenchmark.ExportBenchmark \
        --duration=30 \
        --servers=localhost \
        --statsfile=exportbench.csv
}

function help() {
    echo "Usage: ./run.sh {clean|server|run-benchmark|run-benchmark-help|...}"
}

parse_command_line $@
echo $RUN
# Run the target passed as the first arg on the command line
# If no first arg, run server
if [ -n "$RUN" ]; then $RUN; else server; fi
