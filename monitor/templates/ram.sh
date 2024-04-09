
echo '<div>'
echo '<div>Available RAM:</div>'
echo '<div class="'${RAM_CLASS}'"><span>'${RAM_FREE_GB}/${RAM_TOT_GB}'Gb - '${RAM_FREE_PERC}'%</span></div>'
echo '<div>Unused SWAP:</div>'
echo '<div class="'${SWAP_CLASS}'"><span>'${SWAP_FREE_GB}/${SWAP_TOT_GB}'Gb - '${SWAP_FREE_PERC}'%</span></div>'
echo '</div>'

