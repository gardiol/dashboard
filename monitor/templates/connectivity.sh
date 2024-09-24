
i=0
echo "<div class='monitor_title'>${TITLE}</div>"

echo "<table>"
local MAX_COLUMNS=$(( COLUMNS-1 ))
while [ ${i} -lt ${NUM_ISPS} ]
do
	if [ ${COLUMNS} -gt 1 ]
	then
		if [ ${col} -eq 0 ]
		then
			pre="<tr>"
			post=
			col=1
		elif [ ${col} -ge ${MAX_COLUMNS} ]
		then
			pre=
			post="</tr>"
			col=0
		else
			pre=
			post=
			col=$(( col+1 ))
		fi
	else
		pre="<tr>"
		post="</tr>"
	fi
	echo ${pre}
	echo "<td>"
	echo "<div class='monitor_title'>${ISP_NAME[${i}]}</div>"
	echo "<span>status/online:&nbsp;</span>"
	echo "<span class='${ISP_GW_CLASS[${i}]}'></span>"
	echo "<span class='${ISP_DEST_CLASS[${i}]}'></span>"
	echo "</td>"
	echo ${post}
	i=$(( i+1 ))
done
echo "</table>"
echo "</div>"

