
echo "<div class='monitor_title'>Devices:</div>"
echo "<table>"
N=0
while [ ${N} -lt ${PING_NUM} ]
do
	echo "<tr>"
	echo "<td><span>${PING_HOSTS[${N}]}</span></td>"
	echo "<td><span class='${PING_CLASS[${N}]}'></span></td>"
	echo "</tr>"
	N=$(( N+1 ))
done

echo "</table>"
