
i=0
while [ ${i} -lt ${NUM_ISPS} ]
do
	echo "<div>"
	echo "<div class='monitor_title'>${ISP_NAME[${i}]}</div>"
	echo "<span>status/online:&nbsp;</span>"
	echo "<span class='${ISP_GW_CLASS[${i}]}'></span>"
	echo "<span class='${ISP_DEST_CLASS[${i}]}'></span>"
	echo "</div>"
	i=$(( i+1 ))
done
echo "</div>"

