local rawItemIDs = {
	16309, 12344, 17191, 7146, 12382, 6893, 11000, 11140, 18249, 13704, 11197, 18266, 18268, 13873, 19931, 18250, 9240, 17333, 22754, 13523, 18746, 18663, 19974, 7733, 10818, 22057, 21986,
	20876, 20879, 20875, 20878, 20881, 20877, 20874, 20882, 21762, 21156, 21230, 20864, 20861, 20863, 20862, 20859, 20865, 20860, 20858, 22203, 22202, 21229,
	20728, 20731, 20734, 20729, 20736, 20730, 20727,
	21138, 21529, 21530, 21139, 21531, 21532, 21137, 21517, 21527, 21526, 21025, 21175, 21176, 21523, 21521, 21522, 21520,
	18401, 18362, 18358, 18360, 18356, 18364, 18361, 18363, 18359, 18357, 18333, 18334, 18332, 11733, 11736, 11732, 11734, 11737,
	14149, 14148, 14145, 251361, 251362, 251363, 252782, 14150, 14147, 14151, 251360, 253906, 272996, 272998, 272999, 252781, 273003, 273005, 273007, 252780, 253908, 253910,
	6460, 10410, 6465, 10412, 5404, 6446, 273088, 13245, 6447, 273084, 6472, 6473, 273089, 6449, 6448, 273137, 6469, 5970, 10411, 6459, 6630, 6631, 6629, 6461, 6627, 6463, 10441, 5243, 6632, 10413,
	872, 5187, 273289, 251364, 5443, 5444, 5194, 5195, 285292, 273293, 273092, 253902, 1937, 2169, 1156, 5199, 273297, 252777, 252778, 253904, 273086, 7230, 5192, 5196, 284715, 252779, 5201, 10403, 5200, 5193, 5202, 10399, 5191, 2874, 252799, 252800, 252801, 252803, 253938, 253948, 5198, 5197, 8490, 273298, 253912, 273102, 5397, 8492, 10402, 10401, 10400, 1951, 1929, 1934, 1936,
	5254, 273456, 273457, 6341, 932, 251341, 251381, 253946, 1292, 6226, 6633, 6321, 6323, 273637, 277490, 276631, 6320, 3191, 273643, 273105, 6318, 6319, 273645, 6642, 6641, 5943, 6340, 3230, 273646, 251380, 3748, 6314, 273647, 6324, 6392, 6220, 2292, 1489, 1974, 2807, 1482, 1935, 1483, 1318, 3194, 2205, 1484, 23173, 23171, 51804, 51805, 51806, 51807, 51808, 49641, 49715, 50250, 50446, 50471, 50741, 6895, 6283,
	6907, 6908, 273839, 253944, 6906, 6905, 1470, 252512, 252513, 252456, 252514, 252515, 273840, 251375, 252820, 252821, 252825, 253978, 253980, 273141, 16782, 1155, 6903, 252455, 273846, 252822, 252823, 253982, 6901, 6904, 6902, 6911, 6910, 6909, 251376, 251377, 251378, 252824, 253984, 273841, 273842, 273843, 1486, 3416, 1491, 3414, 1454, 1481, 2567, 3413, 3417, 3415, 2271, 2034,
	2280, 273807, 273808, 251379, 3228, 2941, 2942, 273804, 273805, 273806, 273809, 273810, 273811, 273824, 273825, 273827, 273829, 253976, 253986, 273820, 273817, 273819, 1076, 274092,
	9444, 9445, 274043, 274042, 9454, 9453, 9452, 9447, 9446, 9448, 9449, 9450, 274068, 274049, 9455, 9456, 9457, 9492, 9461, 9458, 9459, 4415, 4413, 4411, 7742, 11828, 9508, 9491, 9509, 9510, 9487, 9485, 9488, 9486, 9490, 9489, 11827, 9327, 7191, 9308, 9326, 9279, 9280, 9282, 9281, 9316,
	6681, 274159, 274158, 2816, 6685, 6682, 6687, 6686, 274161, 6679, 6691, 6690, 274160, 6695, 6697, 6696, 6693, 6694, 6692, 17008, 273103, 6689, 6688, 274152, 274149, 274155, 2264, 1488, 4438, 1978, 2039, 1727, 776, 1976, 1975, 2549,
	7682, 7683, 274290, 7709, 7708, 7731, 7691, 7690, 7689, 7688, 7687, 7686, 7685, 7684, 274291, 5819, 7727, 7728, 7754, 10332, 2262, 7787, 7729, 7761, 7752, 8226, 7786, 7753, 7730, 10328, 10329, 10330, 10331, 10333, 23169, 23170, 23168, 211817, 211844, 211847, 211850, 211851, 33292, 34068, 33277, 37012, 33182, 33176, 33184, 37011, 33154, 7710, 7756, 3456, 7714, 7713, 7712, 7711, 274294, 274293, 7755, 7759, 7760, 1992, 5756, 7736, 8225, 7758, 7757, 7719, 7718, 7717, 23192, 19507, 19508, 19509, 7724, 7726, 7723, 7720, 7722, 7721,
	10776, 10775, 10777, 10769, 10771, 10770, 10774, 10772, 10768, 10767, 10758, 10763, 10762, 10764, 10761, 10765, 10766, 10760, 10574, 10581, 10583, 10584, 10578, 10582, 10572, 10567, 10571, 10570, 10573, 23178, 23177, 3826, 10841,
	9394, 9398, 2459, 9401, 9399, 9400, 9404, 9403, 1177, 9389, 9388, 9390, 9387, 7741, 9409, 9407, 9408, 8053, 9410, 9411, 11310, 9412, 11311, 9419, 9415, 9416, 9414, 7670, 11118, 9413, 9418, 9431, 9429, 9420, 9430, 9397, 9406, 9428, 9432, 9396, 9393, 7666, 9381, 9426, 9422, 9465, 9384, 9386, 9427, 9392, 9424, 9383, 9425, 9423, 9391, 7740, 7671, 7669, 5824,
	9640, 9641, 9639, 9379, 10660, 9523, 18083, 18082, 9471, 9470, 9473, 9474, 9475, 12471, 8444, 8548, 9234, 10661, 9469, 9467, 9479, 9476, 9478, 9477, 11086, 12470, 9512, 9484, 862, 6440, 9483, 2040, 5616, 9511, 9481, 9480, 9482, 9243,
	17765, 17746, 17744, 17745, 17749, 17748, 17750, 17751, 17764, 17755, 17754, 17752, 17767, 17741, 17742, 17740, 17739, 17738, 17734, 17736, 17737, 17943, 17718, 17717, 17719, 17732, 17728, 17730, 17780, 17715, 17707, 17714, 17711, 17713, 17710, 17766, 17757, 17761, 17762, 17763,
	10783, 10784, 10787, 10788, 10785, 10786, 20606, 20607, 20608, 10800, 10798, 10799, 10801, 10802, 12462, 10843, 10845, 10842, 10846, 10838, 10844, 10806, 10808, 10807, 10805, 10803, 10804, 12465, 12466, 12464, 10797, 12463, 12243, 10795, 10796, 10847, 10833, 10829, 10836, 10835, 10837, 10828, 10454, 10630, 10632, 10631, 10633, 10629, 10634, 10624, 10623, 10625, 10626, 10628, 10627, 10782, 10781, 10780, 16216, 15733,
	22234, 11632, 11631, 22397, 11630, 11813, 11626, 11624, 22240, 11625, 11623, 11627, 11628, 11629, 11726, 22271, 22257, 22266, 11722, 11703, 22270, 11702, 11610, 11685, 11679, 11686, 11730, 11665, 11662, 11728, 11824, 11678, 11677, 11675, 11731, 11633, 11634, 11635, 11729, 11747, 11749, 11748, 11750, 11207, 22256, 22205, 22255, 22254, 11923, 11945, 11946, 11752, 11751, 11753, 11782, 22241, 11783, 11784, 11755, 22242, 11839, 22223, 11842, 11841, 11840, 11766, 11764, 11765, 11767, 19268, 11768, 11807, 11802, 11805, 11803, 11820, 11821, 11810, 11817, 11816, 11823, 11822, 11669, 11819, 11735, 18043, 22275, 18044, 18592, 11612, 2662, 2663, 11742, 12793, 12791, 18653, 13483, 15759, 11325, 11602, 22212, 11745, 11744, 11743, 11808, 11812, 11814, 11832, 11809, 23320, 22245, 11787, 11785, 11786, 11925, 11926, 11929, 11927, 11920, 11922, 11921, 11746, 11935, 22395, 22400, 22208, 12557, 12554, 12556, 12553, 11684, 11933, 11930, 11924, 22204, 22207, 11934, 11815, 11928, 11931, 11932, 12033, 12549, 12552, 12551, 12542, 12546, 12550, 12547, 12555, 12527, 12531, 12535, 12528, 12532, 15781, 15770, 11611, 11614, 11615, 16048, 16053, 16049, 18654, 18661, 22305, 22330, 22318, 22317, 49116, 49118, 49074, 49076, 49078, 49080, 49120, 48663, 33977, 37828, 37863, 38280,
	13181, 13182, 12608, 13286, 16670, 13166, 13168, 13170, 13169, 13167, 12336, 12534, 13284, 13285, 13282, 13283, 13261, 16712, 13257, 12626, 13255, 12653, 12651, 12654, 16676, 13177, 13179, 22231, 13173, 12582, 12335, 12637, 12634, 12621, 12838, 16715, 13244, 13213, 13183, 13185, 13184, 13218, 13258, 22232, 13259, 13178, 18784, 13247, 13253, 13252, 12835, 13212, 22313, 13211, 13210, 16718, 13208, 13206, 13205, 13203, 13198, 13204, 13143, 16679, 13162, 13164, 22321, 13163, 13148, 13161, 12337, 12780, 14513, 16696, 16685, 16683, 16703, 16713, 16716, 16680, 16673, 16736, 16735, 15749, 15775, 13494, 16250, 16244, 9214, 12219, 12586, 22306, 22325, 22319, 22398, 22322, 16672, 12929, 12927, 12905, 12926, 16695, 12609, 12603, 12589, 12606, 18657, 12604, 12930, 12605, 13502, 13498, 18047, 18048, 12834, 12837, 18779, 12806, 12696, 12871, 16669, 22225, 12960, 12953, 12952, 13522, 12590, 16733, 12587, 12588, 12936, 18104, 12935, 18102, 22247, 18103, 12940, 12939, 12583, 12731, 16729, 12967, 12968, 12966, 12965, 12963, 12964, 22311, 12709, 12969, 24101, 19227, 12592, 22267, 13141, 22269, 13142, 13098, 22268, 22253, 12602, 15730, 13519, 16690, 16688, 16700, 16721, 16706, 16674, 16666, 16726, 16730, 24102, 13260, 16681, 16247, 12358, 22302, 22340, 22337, 22343, 22342, 22339, 22336, 22335,
	18267, 18319, 18313, 18323, 18308, 18306, 18317, 18322, 18324, 18305, 18307, 18325, 18311, 18301, 18302, 18328, 18312, 18309, 18326, 18327, 18318, 18321, 18310, 18314, 18315, 18289, 18296, 18298, 18295, 18255, 18297, 22304, 22472, 22401, 22345, 22315, 22314, 18393, 18390, 18352, 18353, 18383, 18386, 18349, 18347, 18374, 18397, 18371, 18350, 18351, 22309, 18387, 18346, 18345, 18381, 18384, 18389, 18385, 18394, 18377, 18391, 18379, 18370, 18372, 18382, 18373, 18375, 18378, 18380, 18395, 18388, 18396, 18376, 18392, 18340, 18344, 18338, 23127, 23129, 23128, 18487, 18757, 18754, 18755, 18756, 18494, 18493, 18496, 18497, 18498, 18450, 18458, 18459, 18451, 18462, 18463, 18464, 18460, 18425, 18269, 18284, 18287, 18288, 9260, 18414, 18517, 18518, 18519, 18415, 18416, 18417, 18418, 18514, 18515, 18516, 18258, 18240, 18503, 18505, 18507, 18502, 18490, 18483, 18485, 18484, 18526, 18525, 18527, 18524, 18521, 18522, 18523, 18520, 19258, 18780, 18538, 18528, 18495, 18532, 18530, 18533, 18529, 18500, 18537, 18499, 18531, 18534, 18479, 18480, 18478, 18475, 18477, 18476, 18482, 18481, 18655, 18640,
	13960, 13955, 13969, 13957, 13956, 13967, 14024, 13983, 16701, 14548, 18689, 14543, 14545, 18690, 14541, 22394, 16711, 14539, 14538, 18686, 14537, 14528, 14531, 18782, 18760, 18761, 18758, 18759, 18692, 14576, 18691, 14577, 13314, 16689, 14503, 14340, 18693, 14525, 14502, 14522, 18694, 18695, 18696, 13952, 14487, 13521, 16710, 18681, 14633, 14626, 14637, 14611, 14624, 14629, 14640, 14615, 14622, 14636, 14614, 14620, 14632, 14638, 18682, 14612, 14623, 14631, 14641, 14616, 14621, 18684, 23201, 23200, 18680, 18683, 16684, 14617, 16705, 16722, 13937, 14514, 16693, 16686, 16698, 16707, 16720, 16677, 16667, 16727, 16731, 13944, 13951, 13950, 13398, 22433, 13938, 13953, 13964, 19276, 13501, 16702, 16714, 16671, 12843, 12841, 12840, 20520, 12753, 18698, 18699, 14536, 18700, 18702, 18697, 18701, 16254, 16255, 15773, 15776, 13920, 23132, 23156, 23139, 22303, 22326, 22331, 22332, 22333,
	13395, 13394, 13396, 13303, 13305, 13304, 13307, 13306, 13302, 16682, 13378, 13384, 13383, 13379, 13404, 13405, 13409, 13408, 13390, 13388, 13389, 13391, 13392, 13393, 16724, 13400, 13403, 13402, 13401, 12845, 18781, 16708, 22407, 22403, 22405, 18721, 13381, 13382, 13380, 13377, 22404, 22406, 12839, 16692, 13386, 13387, 18716, 13385, 12811, 22897, 13353, 14512, 16725, 13359, 18718, 12103, 18720, 13358, 13369, 13360, 18717, 22334, 13348, 13520, 13250, 18727, 13376, 18726, 18722, 23198, 18725, 13397, 13954, 13399, 16704, 18728, 18730, 18729, 13534, 13538, 13535, 13537, 13539, 13514, 18783, 16675, 18740, 18739, 18738, 13529, 13533, 13532, 13531, 13530, 13508, 16691, 18734, 18735, 13524, 18737, 13528, 13525, 13526, 13527, 13509, 12833, 16737, 18723, 13374, 13373, 13515, 13375, 13372, 13335, 13505, 22411, 22412, 13340, 13346, 22409, 13344, 22410, 13345, 22408, 13349, 13368, 13361, 16694, 16687, 16699, 16709, 16719, 16678, 16668, 16728, 16732, 16697, 16723, 12735, 18742, 18743, 17061, 18741, 18744, 18745, 18736, 16249, 16248, 14495, 15777, 15768, 18658, 16052, 12827, 12830, 22736, 23126, 23125, 23124, 22327, 22301, 22328, 22329,
	19132, 18208, 18541, 18547, 18545, 19131, 19130, 17070, 18202, 18542, 18704, 11938, 17962, 17963, 17964, 17965, 17969, 18546, 17111, 18204, 19135, 18544, 19134, 19133, 18543, 17112, 17113, 18665, 20628, 20626, 20630, 20625, 20627, 20629, 20579, 20615, 20616, 20618, 20617, 20619, 20582, 20644, 20600, 20580, 20581, 20381, 20623, 20622, 20624, 20621, 20599, 20633, 20631, 20634, 20632, 20577, 20637, 20635, 20638, 20639, 20636, 20578,
	16800, 16805, 16829, 16837, 16859, 16863, 18870, 17109, 19145, 19146, 18872, 18875, 18861, 18879, 19147, 17077, 18878, 16665, 16814, 16796, 16810, 16822, 16835, 16847, 16843, 16855, 16867, 18203, 17065, 18829, 18823, 19143, 19136, 19144, 18824, 18821, 18820, 19142, 17069, 17073, 18822, 16812, 16826, 16849, 16839, 16860, 16862, 18564, 16813, 16795, 16808, 16821, 16834, 16846, 16842, 16854, 16866, 17066, 17071, 17105, 18832, 16811, 16801, 16803, 16824, 16831, 16852, 18563, 16797, 16807, 16836, 16844, 16856, 17110, 16815, 16798, 16809, 16820, 16833, 16845, 16841, 16853, 16865, 17203, 17072, 17103, 18842, 16816, 16823, 16848, 16868, 17074, 19139, 18810, 18811, 18808, 18809, 18812, 18806, 19140, 18805, 18803, 18703, 18646, 17204, 19017, 16922, 16915, 16930, 16909, 16901, 16938, 16946, 16954, 16962, 17082, 18817, 18814, 17102, 17107, 19137, 17063, 19138, 18815, 17106, 18816, 17104, 17076, 18264, 18292, 18291, 18290, 18259, 18260, 18252, 18265, 21371, 18257, 16817, 16802, 16806, 16827, 16828, 16851, 16838, 16858, 16864, 17011, 17010, 11382, 17012, 16819, 16799, 16804, 16825, 16830, 16850, 16840, 16857, 16861,
	16921, 16914, 16929, 16908, 16900, 16939, 16947, 16955, 16963, 18422, 18423, 15410, 18705, 18205, 17078, 18813, 17064, 17067, 17068, 17075, 17966,
	19721, 19724, 19723, 19722, 19717, 19716, 19718, 19719, 19720, 19918, 19923, 19928, 20262, 20265, 19920, 19915, 19904, 19903, 19907, 19906, 19905, 19900, 20032, 19927, 19871, 19919, 19925, 19930, 22637, 19872, 20038, 19867, 19866, 19874, 19878, 19870, 19869, 19895, 19877, 19873, 19863, 19893, 19961, 19962, 19939, 19967, 19968, 19942, 19964, 19963, 19940, 19993, 19965, 19941, 19945, 19944, 19947, 19946, 22739, 19902, 19897, 19896, 19899, 20260, 20266, 19898, 19901, 19910, 19909, 19913, 19912, 19922, 19914, 19885, 19891, 19890, 19884, 19886, 19875, 19888, 19929, 19894, 19889, 19887, 19892, 19857, 20257, 20264, 19855, 19876, 19856, 19802, 19861, 19853, 19862, 19864, 19865, 19852, 19859, 19854, 22721, 22722, 22720, 22718, 22711, 22712, 22715, 22714, 22716, 22713, 20263, 20259, 20261, 19921, 19908, 20258, 19726, 19774, 19767, 19768, 19706, 19701, 19700, 19699, 19704, 19705, 19702, 19703, 19698, 19708, 19713, 19715, 19711, 19710, 19712, 19707, 19714, 19709, 19789, 19787, 19788, 19784, 19790, 19785, 19786, 19783, 19782, 20077, 20076, 20078, 22635, 19975, 19727, 19820, 19818, 19819, 19814, 19821, 19816, 19817, 19815, 19813,
	16926, 16918, 16934, 16911, 16904, 16935, 16943, 16951, 16959, 19336, 19337, 19370, 19369, 19335, 19334, 16925, 16818, 16933, 16910, 16903, 16936, 16944, 16952, 16960, 19339, 19340, 19372, 19371, 19348, 19346, 16919, 16912, 16927, 16906, 16898, 16941, 16949, 16957, 16965, 19341, 19342, 19373, 19374, 19350, 19351, 20383, 16920, 16913, 16928, 16907, 16899, 16940, 16948, 16956, 16964, 19344, 19343, 19394, 19398, 19399, 19400, 19396, 19401, 19402, 19365, 19353, 19355, 19397, 19395, 19345, 19406, 19407, 19405, 19368, 19403, 19431, 19430, 19433, 19367, 19357, 19432, 16924, 16917, 16932, 16832, 16902, 16937, 16945, 16953, 16961, 19389, 19386, 19390, 19388, 19393, 19392, 19385, 19391, 19387, 19361, 19349, 19347, 19352, 16923, 16916, 16931, 16905, 16897, 16942, 16950, 16958, 16966, 19002, 19003, 19360, 19363, 19364, 19356, 19375, 19377, 19378, 19380, 19381, 19376, 19382, 19379, 19436, 19439, 19437, 19438, 19434, 19435, 19362, 19354, 19358, 18562,
	21499, 21498, 21502, 21501, 21500, 21503, 20885, 20889, 20888, 20884, 21493, 21492, 21496, 21494, 21495, 21497, 21810, 21809, 21806, 21472, 21467, 21479, 21471, 21455, 21468, 21474, 21470, 21469, 21476, 21475, 21477, 21473, 20890, 20886, 22220, 22194, 21487, 21486, 21485, 21491, 21489, 21490, 21488, 21478, 21466, 21484, 21480, 21482, 21481, 21483, 21460, 21454, 21453, 21456, 21464, 21457, 21462, 21458, 21463, 21461, 21459, 21715, 21452, 21220, 21804, 21803, 21805, 20873, 20869, 20866, 20870, 20868, 20871, 20867, 20872, 21761, 21801, 21800, 21802, 21284, 21287, 21285, 21279, 21214, 21280, 21281, 21283, 21282, 21300, 21303, 21302, 21294, 21296, 21295, 21306, 21304, 21307, 21291, 21292, 21293, 21288, 21289, 21290, 21298, 21299, 21297,
	21699, 21814, 21708, 21698, 21705, 21704, 21706, 21702, 21700, 21701, 21707, 21703, 21128, 21237, 21232, 22222, 21693, 21694, 21697, 21696, 21692, 21695, 21680, 21681, 21685, 21603, 21690, 21689, 21691, 21688, 21686, 21684, 21683, 21682, 21687, 21669, 21678, 21671, 21672, 21674, 21675, 21676, 21668, 21667, 21648, 21670, 21666, 21673, 21665, 21639, 21627, 21663, 21652, 21651, 21645, 21650, 21635, 21664, 21647, 22402, 22396, 21624, 21623, 21626, 21622, 21677, 21625, 22399, 20928, 20932, 21621, 21618, 21619, 21617, 21620, 21616, 20930, 21602, 21599, 21598, 21600, 21601, 21597, 20735, 20926, 21608, 21604, 21605, 21609, 21607, 21606, 21679, 20726, 21615, 21611, 23558, 23570, 21610, 23557, 20927, 20931, 22732, 21583, 22731, 22730, 21582, 21586, 21585, 21581, 21596, 21579, 21839, 21126, 21134, 20929, 20933, 21221, 22734, 21838, 21888, 21889, 21856, 21837, 21836, 21891, 21218, 21324, 21323, 21321, 21890,
	22726, 22727, 22369, 22362, 22355, 22935, 22938, 22936, 22939, 22937, 22943, 22941, 22940, 22942, 22806, 22371, 22364, 22357, 22947, 23220, 22954, 22807, 22804, 22370, 22363, 22356, 23030, 23031, 23028, 23029, 23006, 23005, 22816, 23035, 23033, 23019, 23036, 23068, 22366, 22359, 22352, 23038, 23037, 23042, 23039, 22800, 22372, 22365, 22358, 23017, 23219, 23018, 23004, 23009, 23014, 23032, 23020, 23023, 23021, 23073, 22351, 22350, 22349, 23071, 23025, 23027, 22811, 22809, 22691, 22368, 22361, 22354, 22960, 22961, 22820, 22818, 22815, 22968, 22967, 22810, 22803, 22988, 22983, 22981, 22994, 23075, 22813, 22367, 22360, 22353, 23000, 23070, 23001, 22808, 22801, 23050, 23045, 23040, 23047, 23041, 23046, 23049, 23048, 23043, 23242, 23549, 23548, 23545, 23547, 23072, 23057, 23053, 22812, 22821, 22819, 22802, 23056, 23054, 23577, 22798, 22799, 22520, 23061, 23062, 23063, 23060, 23064, 23067, 23065, 23066, 23059, 22733, 23664, 23667, 23069, 23226, 23663, 23666, 23665, 23668, 23237, 23238, 23044, 23221, 22376, 22373, 22374, 22375, 23055, 22682,
	270227, 271096, 271097, 270230, 270231, 271095, 270228, 270229, 271098, 270256, 270260, 270261, 271204, 271205, 271206, 271201, 271202, 271203, 271207, 271208, 271216, 271209, 271210, 271217, 271213, 271214, 271215, 271211, 271212, 271218, 273022, 273023, 273024, 273025, 273026, 273027, 273028, 273030, 273029, 273032, 273033, 273036, 273031, 273034, 273035, 273043, 273044, 273045, 273046, 273047, 273048, 273040, 273041, 273042, 273037, 273038, 273039, 273053, 273054, 273055, 273049, 273051, 273052
}

local itemDatabase = {}
local seenIDs = {}
for i = 1, #rawItemIDs do
	local id = rawItemIDs[i]
	if id and id > 0 and not seenIDs[id] then
		seenIDs[id] = true
		table.insert(itemDatabase, id)
	end
end
table.sort(itemDatabase)

AtlasFavListDB = AtlasFavListDB or {}

local currentTab = "ALL"
local selectedList = "Favorites"
local currentSearch = ""
local filteredItems = {}

local function InitializeDB()
	if not AtlasFavListDB.lists then
		AtlasFavListDB.lists = {
			["Favorites"] = {}
		}
	end
	if not AtlasFavListDB.lists["Favorites"] then
		AtlasFavListDB.lists["Favorites"] = {}
	end
	if not AtlasFavListDB.activeList or not AtlasFavListDB.lists[AtlasFavListDB.activeList] then
		AtlasFavListDB.activeList = "Favorites"
	end
	selectedList = AtlasFavListDB.activeList
end

local MainFrame = CreateFrame("Frame", "AtlasFavListMainFrame", UIParent, "BackdropTemplate")
MainFrame:SetSize(460, 520)
MainFrame:SetPoint("CENTER")
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
MainFrame:SetClampedToScreen(true)
MainFrame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
MainFrame:Hide()

local Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
Title:SetPoint("TOP", 0, -14)
Title:SetText("Atlas Loot Favorites")

local CloseButton = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
CloseButton:SetPoint("TOPRIGHT", -5, -5)

local TabAll = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
TabAll:SetSize(100, 24)
TabAll:SetPoint("TOPLEFT", 18, -45)
TabAll:SetText("All Items")

local TabFav = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
TabFav:SetSize(100, 24)
TabFav:SetPoint("LEFT", TabAll, "RIGHT", 5, 0)
TabFav:SetText("Favorites")

local SearchBox = CreateFrame("EditBox", nil, MainFrame, "InputBoxTemplate")
SearchBox:SetSize(160, 20)
SearchBox:SetPoint("TOPRIGHT", -22, -47)
SearchBox:SetAutoFocus(false)

local SearchLabel = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
SearchLabel:SetPoint("RIGHT", SearchBox, "LEFT", -6, 0)
SearchLabel:SetText("Search:")

local FavControlBar = CreateFrame("Frame", nil, MainFrame)
FavControlBar:SetSize(420, 30)
FavControlBar:SetPoint("TOPLEFT", 18, -75)

local ListDropdown = CreateFrame("Frame", "AtlasFavListDropdown", FavControlBar, "UIDropDownMenuTemplate")
ListDropdown:SetPoint("LEFT", -15, -2)
UIDropDownMenu_SetWidth(ListDropdown, 140)

local NewListBtn = CreateFrame("Button", nil, FavControlBar, "UIPanelButtonTemplate")
NewListBtn:SetSize(80, 22)
NewListBtn:SetPoint("LEFT", ListDropdown, "RIGHT", -5, 2)
NewListBtn:SetText("New List")

local DelListBtn = CreateFrame("Button", nil, FavControlBar, "UIPanelButtonTemplate")
DelListBtn:SetSize(80, 22)
DelListBtn:SetPoint("LEFT", NewListBtn, "RIGHT", 4, 0)
DelListBtn:SetText("Delete List")

local NewListDialog = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
NewListDialog:SetSize(280, 110)
NewListDialog:SetPoint("CENTER", 0, 20)
NewListDialog:SetFrameStrata("DIALOG")
NewListDialog:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
NewListDialog:Hide()

local NewListText = NewListDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
NewListText:SetPoint("TOP", 0, -15)
NewListText:SetText("Enter Favorite List Name:")

local NewListEdit = CreateFrame("EditBox", nil, NewListDialog, "InputBoxTemplate")
NewListEdit:SetSize(200, 20)
NewListEdit:SetPoint("CENTER", 0, -5)
NewListEdit:SetAutoFocus(false)

local NewListOK = CreateFrame("Button", nil, NewListDialog, "UIPanelButtonTemplate")
NewListOK:SetSize(75, 22)
NewListOK:SetPoint("BOTTOMLEFT", 45, 12)
NewListOK:SetText("Create")

local NewListCancel = CreateFrame("Button", nil, NewListDialog, "UIPanelButtonTemplate")
NewListCancel:SetSize(75, 22)
NewListCancel:SetPoint("BOTTOMRIGHT", -45, 12)
NewListCancel:SetText("Cancel")

local ScrollFrame = CreateFrame("ScrollFrame", "AtlasFavListScrollFrame", MainFrame, "FauxScrollFrameTemplate")
ScrollFrame:SetSize(388, 380)
ScrollFrame:SetPoint("TOPLEFT", 20, -112)

local NUM_ROWS = 10
local ROW_HEIGHT = 38
local Rows = {}

local function UpdateListDropdown()
	local function OnClick(self)
		UIDropDownMenu_SetSelectedValue(ListDropdown, self.value)
		selectedList = self.value
		AtlasFavListDB.activeList = selectedList
		MainFrame:Refresh()
	end

	UIDropDownMenu_Initialize(ListDropdown, function()
		local info = UIDropDownMenu_CreateInfo()
		if AtlasFavListDB and AtlasFavListDB.lists then
			for listName in pairs(AtlasFavListDB.lists) do
				info.text = listName
				info.value = listName
				info.func = OnClick
				info.checked = (listName == selectedList)
				UIDropDownMenu_AddButton(info)
			end
		end
	end)
	UIDropDownMenu_SetSelectedValue(ListDropdown, selectedList)
	UIDropDownMenu_SetText(ListDropdown, selectedList)
end

local function IsItemInList(itemID, listName)
	if not AtlasFavListDB.lists or not AtlasFavListDB.lists[listName] then return false end
	for i = 1, #AtlasFavListDB.lists[listName] do
		if AtlasFavListDB.lists[listName][i] == itemID then
			return true
		end
	end
	return false
end

local function AddItemToList(itemID, listName)
	if not AtlasFavListDB.lists[listName] then
		AtlasFavListDB.lists[listName] = {}
	end
	if not IsItemInList(itemID, listName) then
		table.insert(AtlasFavListDB.lists[listName], itemID)
	end
end

local function RemoveItemFromList(itemID, listName)
	if not AtlasFavListDB.lists[listName] then return end
	for i = 1, #AtlasFavListDB.lists[listName] do
		if AtlasFavListDB.lists[listName][i] == itemID then
			table.remove(AtlasFavListDB.lists[listName], i)
			break
		end
	end
end

local function RebuildFilteredItems()
	filteredItems = {}
	local source = (currentTab == "ALL") and itemDatabase or (AtlasFavListDB.lists[selectedList] or {})
	local searchLower = string.lower(currentSearch or "")

	for i = 1, #source do
		local id = source[i]
		local name = GetItemInfo(id)
		local matches = false

		if searchLower == "" then
			matches = true
		elseif tostring(id):find(searchLower, 1, true) then
			matches = true
		elseif name and string.lower(name):find(searchLower, 1, true) then
			matches = true
		end

		if matches then
			table.insert(filteredItems, id)
		end
	end
end

function MainFrame:Refresh()
	RebuildFilteredItems()
	local numItems = #filteredItems
	FauxScrollFrame_Update(ScrollFrame, numItems, NUM_ROWS, ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(ScrollFrame)

	for i = 1, NUM_ROWS do
		local rowIndex = offset + i
		local row = Rows[i]

		if rowIndex <= numItems then
			local itemID = filteredItems[rowIndex]
			row.itemID = itemID

			local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(itemID)

			if not texture then
				texture = "Interface\\Icons\\INV_Misc_QuestionMark"
			end
			row.icon:SetTexture(texture)

			if name and link then
				row.nameText:SetText(link)
			else
				row.nameText:SetText("Item #" .. itemID)
			end

			row.idText:SetText("ID: " .. itemID)

			if currentTab == "ALL" then
				if IsItemInList(itemID, selectedList) then
					row.actionBtn:SetText("Saved")
					row.actionBtn:Disable()
				else
					row.actionBtn:SetText("+ Fav")
					row.actionBtn:Enable()
				end
			else
				row.actionBtn:SetText("Remove")
				row.actionBtn:Enable()
			end

			row:Show()
		else
			row:Hide()
		end
	end
end

for i = 1, NUM_ROWS do
	local row = CreateFrame("Button", nil, MainFrame, "BackdropTemplate")
	row:SetSize(380, ROW_HEIGHT - 2)
	row:SetPoint("TOPLEFT", ScrollFrame, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
	row:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	row:SetBackdropColor(0.1, 0.1, 0.1, 0.7)

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(30, 30)
	icon:SetPoint("LEFT", 4, 0)
	row.icon = icon

	local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
	nameText:SetPoint("RIGHT", -75, 0)
	nameText:SetJustifyH("LEFT")
	row.nameText = nameText

	local idText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	idText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 2)
	idText:SetJustifyH("LEFT")
	row.idText = idText

	local actionBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	actionBtn:SetSize(65, 22)
	actionBtn:SetPoint("RIGHT", -4, 0)
	row.actionBtn = actionBtn

	actionBtn:SetScript("OnClick", function()
		if not row.itemID then return end
		if currentTab == "ALL" then
			AddItemToList(row.itemID, selectedList)
		else
			RemoveItemFromList(row.itemID, selectedList)
		end
		MainFrame:Refresh()
	end)

	row:SetScript("OnEnter", function(self)
		if not self.itemID then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink("item:" .. self.itemID)
		GameTooltip:Show()
	end)

	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	row:SetScript("OnClick", function(self)
		if not self.itemID then return end
		local _, link = GetItemInfo(self.itemID)
		if link and HandleModifiedItemClick then
			HandleModifiedItemClick(link)
		end
	end)

	Rows[i] = row
end

ScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
	FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
		MainFrame:Refresh()
	end)
end)

TabAll:SetScript("OnClick", function()
	currentTab = "ALL"
	TabAll:Disable()
	TabFav:Enable()
	MainFrame:Refresh()
end)

TabFav:SetScript("OnClick", function()
	currentTab = "FAV"
	TabAll:Enable()
	TabFav:Disable()
	MainFrame:Refresh()
end)

SearchBox:SetScript("OnTextChanged", function(self)
	currentSearch = self:GetText()
	MainFrame:Refresh()
end)

NewListBtn:SetScript("OnClick", function()
	NewListEdit:SetText("")
	NewListDialog:Show()
	NewListEdit:SetFocus()
end)

NewListCancel:SetScript("OnClick", function()
	NewListDialog:Hide()
end)

NewListOK:SetScript("OnClick", function()
	local name = NewListEdit:GetText()
	if name and name:gsub("%s+", "") ~= "" then
		name = name:match("^%s*(.-)%s*$")
		if not AtlasFavListDB.lists[name] then
			AtlasFavListDB.lists[name] = {}
		end
		selectedList = name
		AtlasFavListDB.activeList = selectedList
		UpdateListDropdown()
		NewListDialog:Hide()
		MainFrame:Refresh()
	end
end)

NewListEdit:SetScript("OnEnterPressed", function()
	NewListOK:GetScript("OnClick")()
end)

NewListEdit:SetScript("OnEscapePressed", function()
	NewListDialog:Hide()
end)

DelListBtn:SetScript("OnClick", function()
	local count = 0
	for _ in pairs(AtlasFavListDB.lists) do
		count = count + 1
	end
	if count <= 1 then return end

	AtlasFavListDB.lists[selectedList] = nil
	for nextList in pairs(AtlasFavListDB.lists) do
		selectedList = nextList
		break
	end
	AtlasFavListDB.activeList = selectedList
	UpdateListDropdown()
	MainFrame:Refresh()
end)

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

EventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
		InitializeDB()
		UpdateListDropdown()
		TabAll:Disable()
		TabFav:Enable()
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		if MainFrame:IsShown() then
			MainFrame:Refresh()
		end
	end
end)

SLASH_ATLASFAVLIST1 = "/atlasfavlist"
SlashCmdList["ATLASFAVLIST"] = function()
	InitializeDB()
	UpdateListDropdown()
	if MainFrame:IsShown() then
		MainFrame:Hide()
	else
		MainFrame:Show()
		MainFrame:Refresh()
	end
end