
echo "<div>"
echo "<div><div class=''>Devices:</div>"

N=0
while [ ${N} -lt ${PING_NUM} ]
do
	echo "<div><span class='${PING_CLASS[${N}]}'>${PING_HOSTS[${N}]}</span></div>"
	N=$(( N+1 ))
done

echo "</div>"
