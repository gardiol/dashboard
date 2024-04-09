
echo "<div>"
echo "<div><div class=''>Devices:</div>"

N=0
while [ ${N} -lt ${PING_NUM} ]
do
	if [ ${PING_STATUS[${N}]} -eq 0 ]
	then
		value="-up-";
	else
		value="down";
	fi
	echo "<div><span class='${PING_CLASS[${N}]}'>${PING_HOSTS[${N}]}: </span><span class='${PING_CLASS[${N}]}'>${value}</span></div>"
	N=$(( N+1 ))
done

echo "</div>"
