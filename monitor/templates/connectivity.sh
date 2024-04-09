
echo "<div>"
i=0
while [ ${i} -lt ${NUM_ISPS} ]
do
	echo "<div><span class='normal'>${ISP_NAME[${i}]}: </span><span class='${ISP_GW_CLASS[${i}]}'>gateway</span> / <span class='${ISP_DEST_CLASS[${i}]}'>online</div>"
	

	i=$(( i+1 ))
done
echo "</div>"

