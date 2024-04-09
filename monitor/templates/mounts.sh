
echo '<div><div>Mounts:</div>'
i=0
while [ ${i} -lt ${NUM_MOUNTS} ]
do
	echo "<div class='${MOUNT_CLASS[${i}]}'>${MOUNT_NAME[${i}]}: ${MOUNT_PER[${i}]}%</div>"
	
	i=$(( i+1 ))
done
echo '</div>'
