#!/bin/bash

source monitor.conf

function calculate_cpu()
{
sleepDurationSeconds=1

# read cpu stats to arrays
readarray -t previousStats < <( awk '/^cpu /{flag=1}/^intr/{flag=0}flag' /proc/stat )
sleep $sleepDurationSeconds
readarray -t currentStats < <( awk '/^cpu /{flag=1}/^intr/{flag=0}flag' /proc/stat )

# loop through the arrays
for i in "${!previousStats[@]}"; do
  # Break up arrays 1 line sting into an array element for each item in string
  previousStat_elemant_array=(${previousStats[i]})
  currentStat_elemant_array=(${currentStats[i]})

  # Get all columns from user to steal
  previousStat_colums="${previousStat_elemant_array[@]:1:7}"
  currentStat_colums="${currentStat_elemant_array[@]:1:7}"

  # Replace the column seperator (space) with +
  previous_cpu_sum=$((${previousStat_colums// /+}))
  current_cpu_sum=$((${currentStat_colums// /+}))

  # Get the delta between two reads
  cpu_delta=$((current_cpu_sum - previous_cpu_sum)) 

  # Get the idle time Delta
  cpu_idle=$((currentStat_elemant_array[4]- previousStat_elemant_array[4]))

  # Calc time spent working
  cpu_used=$((cpu_delta - cpu_idle)) 

  # Calc percentage
  cpu_usage=$((100 * cpu_used / cpu_delta))

  # Get cpu used for calc cpu percentage used
  cpu_used_for_calc="${currentStat_elemant_array[0]}"

  if [[ "$cpu_used_for_calc" == "cpu" ]]; then
    export CPU_TOT="$cpu_usage"
#    echo "total: "$cpu_usage"%"
#  else
#    echo $cpu_used_for_calc": "$cpu_usage"%"
  fi
done
}

function parse_loadavg()
{
	local data=($(cat /proc/loadavg))
	export AVG_1=${data[0]}
	export AVG_5=${data[1]}
	export AVG_15=${data[2]}
}

function parse_mountpoint()
{
	local mp=$1
	local data=($(df -h "${mp}" | grep "${mp}"))
	#local data=($(df -h | grep /deposito | awk '{print $1, $2, $3, $4, $5}'))
	export MP_DEV=${data[0]}
	export MP_TOT=${data[1]}
	export MP_USE=${data[2]}
	export MP_FRE=${data[3]}
	export MP_PER=${data[4]}
}

function parse_meminfo()
{
	local tot=($(cat /proc/meminfo | grep "MemTotal:"))
	local fre=($(cat /proc/meminfo | grep "MemFree:"))
	local ava=($(cat /proc/meminfo | grep "MemAvailable:"))
	export MEM_TOT=${tot[1]}
	export MEM_FRE=${fre[1]}
	export MEM_AVA=${ava[1]}
}

function parse_pidstatus()
{
	local pid=$1
	export PID_RUN=0
	if [ -e "/proc/${pid}/status" ]
	then
		export PID_RUN=1
	fi
}

function ping_test()
{
	local dest=$1
	ping -c 1 -W 1 ${dest} > /dev/null 2> /dev/null
	if [ $? -eq 0 ]
	then
		export PING_OK=1
	else
		export PING_OK=0
	fi
}

function connectivity_test()
{
	local gateway=$1
	local destination=$2
	# Test ISP
	ping_test ${gateway}
	if [ ${PING_OK} -eq 1 ]
	then
		export GATEWAY_TEST=1
		ping_test ${destination}
		if [ ${PING_OK} -eq 1 ]
		then
			export DESTINATION_TEST=1
		else
			export DESTINATION_TEST=0
		fi
	else
		export GATEWAY_TEST=0
	fi
}

function print_connectivity()
{
	for isp in ${UPLINKS}
	do
		local name=${isp%%:*}
		local gw_dest=${isp#*:}
		local gw=${gw_dest%%:*}
		local dest=${gw_dest##*:}
		connectivity_test ${gw} ${dest}
		echo "<div><div class=''>${name}</div>"
		if [ $GATEWAY_TEST -eq 1 ]
		then
			class="ok"
			value="-up-";
		else
			class="ko"
			value="down";
		fi
		echo "<div><span class='normal'>Gateway: </span><span class='${class}'>${value}</span></div>"
	
		if [ $DESTINATION_TEST -eq 1 ]
		then
			class="ok"
			value="-up-";
		else
			class="ko"
			value="down";
		fi
		echo "<div><span class='normal'>Routing: </span><span class='${class}'>${value}</span></div>"
		echo "</div>"
	done
}

function print_pings()
{
	echo "<div><div class=''>Devices:</div>"
	for p in ${PINGS}
	do
		name=${p%:*}
		destination=${p#*:}
		echo "<div>"
		ping_test ${destination}
		if [ ${PING_OK} -eq 1 ]
		then
			class="ok"
			value="-up-";
		else
			class="ko"
			value="down";
		fi
		echo "<div><span class='normal'>${name}: </span><span class='${class}'>${value}</span></div>"
		echo "</div>"
	done
}

function print_mounts()
{
	echo '<div><div>Mounts:</div>'
	for mp in ${MOUNTPOINTS}
	do
		name=${mp%%:*}
		point=${mp##*:}
		parse_mountpoint "${point}"
		if [ ${MP_PER%%%} -lt ${FILESYSTEM_LIMIT} ]
		then
			class="ok"
		else
			class="ko"
		fi
		echo "<div class='${class}'>${name}: ${MP_PER}</div>"
	done
	echo '</div>'
}

function print_services()
{
	echo '<div>'
	local step=0
	for service in ${SERVICES_PIDS}
	do
		name=${service%%:*}
		pid_file=${service##*:}
		PID_RUN=0
		if [ -e ${pid_file} ]
		then
			parse_pidstatus $(cat ${pid_file})
		fi
		if [ ${PID_RUN} -eq 1 ]
		then
			class="ok"
		else
			class="ko"
		fi
		if [ ${step} -eq 0 ]
		then
			step=1
			echo "<div><span class='${class}'>${name}</span>"
		else
			step=0
			echo "<span class='${class}'>${name}</span></div>"
		fi
	done
	echo '</div>'
}

function print_load()
{
	parse_loadavg
	local class_1m="normal"
	local class_5m="normal"
	local class_15m="normal"
	test ${AVG_1%%.*} -gt ${LOAD_MAX} && class_1m="ko"
	test ${AVG_1%%.*} -lt ${LOAD_MIN} && class_1m="ok"
	test ${AVG_5%%.*} -gt ${LOAD_MAX} && class_5m="ko"
	test ${AVG_5%%.*} -lt ${LOAD_MIN} && class_5m="ok"
	test ${AVG_15%%.*} -gt ${LOAD_MAX} && class_15m="ko"
	test ${AVG_15%%.*} -lt ${LOAD_MIN} && class_15m="ok"

	echo '<div><div>Load average: </div>'
	echo '<div><span class="'${class_1m}'">'${AVG_1}'(1min)</span></div>'
	echo '<div><span class="'${class_5m}'">'${AVG_5}'(5min)</span></div>'
	echo '<div><span class="'${class_15m}'">'${AVG_15}'(15min)</span></div>'
}

function print_ram()
{
	parse_meminfo
	echo '<div><div>RAM memory:</div>'
	let mem_per=$(( ${MEM_AVA} * 100 /${MEM_TOT} ))
	if [ ${mem_per} -gt ${MEMORY_LIMIT} ]
	then
		class="ok"
	else
		class="ko"
	fi
	echo '<div class="'${class}'"><span>'$(( MEM_AVA/1024/1024 )).$(( MEM_AVA/1024%1024/10 ))/$(( MEM_TOT/1024/1024 )).$(( MEM_TOT/1024%1024/10 ))'Gb</span></div>'
	echo '<div class="'${class}'"><span>'${mem_per}'% free</span></div>' 
	echo '</div>'
}

echo "Content-type: text/html"
echo ""
echo '<link rel="stylesheet" href="'${BASE_UR}'site.css?ver=8"/>'

called_as=${0##*/}
for p in ${PAGES}
do
	page=${p%%:*}
	what=${p#*:}
	if [ "${page}" = "${called_as}" ]
	then
		last_what=""
		while [ "${what}" != "${last_what}" ]
		do
			item=${what%%:*}
			print_${item}
			last_what=${what}
			what=${what#*:}
		done
	fi
done

