
echo "<div class='monitor_title'>Mounts:</div>"
echo "<table>"
i=0
while [ ${i} -lt ${NUM_MOUNTS} ]
do
	echo "<tr>"
	echo "<td><span>${MOUNT_NAME[${i}]}: ${MOUNT_PER[${i}]}%</span></td>"
	echo "<td><span class='${MOUNT_CLASS[${i}]}'></span></td>"
	echo "</tr>"
	i=$(( i+1 ))
done
echo "</table>"

