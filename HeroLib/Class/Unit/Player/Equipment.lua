--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local _, NAG          = ...
local HL                     = NAG.HL
-- HeroLib
local Cache, Utils           = NAG.Cache, HL.Utils
local Unit                   = HL.Unit
local Player, Pet, Target    = Unit.Player, Unit.Pet, Unit.Target
local Focus, MouseOver       = Unit.Focus, Unit.MouseOver
local Arena, Boss, Nameplate = Unit.Arena, Unit.Boss, Unit.Nameplate
local Party, Raid            = Unit.Party, Unit.Raid
local Spell                  = HL.Spell
local Item                   = HL.Item

-- Base API locals
local GetInventoryItemID     = GetInventoryItemID
-- Accepts: unitID, invSlotId; Returns: itemId (number)
local GetProfessionInfo      = GetProfessionInfo
local GetProfessions         = GetProfessions
-- Accepts: nil; Returns: prof1 (number), prof2 (number), archaeology (number), fishing (number), cooking (number)

-- Lua locals
local select                 = select
local wipe                   = wipe

-- File Locals
local Equipment              = {}
local UseableItems           = {}


--- ============================ CONTENT =============================
-- Define our tier set tables
-- TierSets[TierNumber][ClassID][ItemSlot] = Item ID

--TODO: Verify
local TierSets = {
  [11] = {
    [1] = {
      { [1] = {65266, 60325}, [3] = {65268, 60327}, [5] = {65264, 60323}, [7] = {65267, 60324}, [10] = {60326, 65265} }, -- Earthen Warplate
      { [1] = {60328, 65271}, [3] = {60331, 65273}, [5] = {60329, 65269}, [7] = {60330, 65272}, [10] = {65270, 60332} }, -- Earthen Battleplate
    },
    [2] = {
      { [1] = {65216, 60346}, [3] = {65218, 60348}, [5] = {65214, 60344}, [7] = {60347, 65217}, [10] = {65215, 60345} }, -- Reinforced Sapphirium Battleplate
      { [1] = {65226, 60356}, [3] = {65228, 60358}, [5] = {65224, 60354}, [7] = {65227, 60357}, [10] = {65225, 60355} }, -- Reinforced Sapphirium Battlearmor
      { [1] = {65221, 60359}, [3] = {65223, 60362}, [5] = {60360, 65219}, [7] = {65222, 60361}, [10] = {65220, 60363} }, -- Reinforced Sapphirium Regalia
    },
    [3] = {
      { [1] = {65206, 60303}, [3] = {65208, 60306}, [5] = {60304, 65204}, [7] = {65207, 60305}, [10] = {65205, 60307} }, -- Lightning-Charged Battlegear
    },
    [4] = {
      { [1] = {65241, 60299}, [3] = {65243, 60302}, [5] = {65239, 60301}, [7] = {60300, 65242}, [10] = {60298, 65240} }, -- Wind Dancer's Regalia
    },
    [5] = {
      { [1] = {60258, 65230}, [3] = {65233, 60262}, [5] = {65232, 60259}, [7] = {60261, 65231}, [10] = {60275, 65229} }, -- Mercurial Vestments
      { [1] = {65235, 60256}, [3] = {65238, 60253}, [5] = {65237, 60254}, [7] = {65236, 60255}, [10] = {65234, 60257} }, -- Mercurial Regalia
    },
    [6] = {
      { [1] = {65181, 60341}, [3] = {65183, 60343}, [5] = {65179, 60339}, [7] = {65182, 60342}, [10] = {65180, 60340} }, -- Magma Plated Battlegear
      { [1] = {65186, 60351}, [3] = {65188, 60353}, [5] = {65184, 60349}, [7] = {65187, 60352}, [10] = {65185, 60350} }, -- Magma Plated Battlearmor
    },
    [7] = {
      { [1] = {60308, 65246}, [3] = {65248, 60311}, [5] = {60309, 65244}, [7] = {65247, 60310}, [10] = {65245, 60312} }, -- Vestments of the Raging Elements
      { [1] = {65256, 60315}, [3] = {65258, 60317}, [5] = {65254, 60313}, [7] = {65257, 60316}, [10] = {60314, 65255} }, -- Regalia of the Raging Elements
      { [1] = {65251, 60320}, [3] = {65253, 60322}, [5] = {65249, 60318}, [7] = {60321, 65252}, [10] = {65250, 60319} }, -- Battlegear of the Raging Elements
    },
    [8] = {
      { [1] = {65210, 60243}, [3] = {65213, 60246}, [5] = {65212, 60244}, [7] = {65211, 60245}, [10] = {65209, 60247} }, -- Firelord's Vestments
    },
    [9] = {
      { [1] = {65260, 60249}, [3] = {65263, 60252}, [5] = {60251, 65262}, [7] = {60250, 65261}, [10] = {65259, 60248} }, -- Shadowflame Regalia
    },
    [11] = {
      { [1] = {65200, 60282}, [3] = {60284, 65203}, [5] = {65202, 60281}, [7] = {65201, 60283}, [10] = {65199, 60285} }, -- Stormrider's Regalia
      { [1] = {65195, 60277}, [3] = {65198, 60279}, [5] = {60276, 65197}, [7] = {60278, 65196}, [10] = {60280, 65194} }, -- Stormrider's Vestments
      { [1] = {65190, 60286}, [3] = {60289, 65193}, [5] = {65192, 60287}, [7] = {65191, 60288}, [10] = {60290, 65189} }, -- Stormrider's Battlegarb
    },
  },
  [12] = {
    [1] = {
      { [1] = {71070, 71599}, [3] = {71603, 71072}, [5] = {71600, 71068}, [7] = {71602, 71071}, [10] = {71601, 71069} }, -- Molten Giant Warplate
      { [1] = {71606, 70944}, [3] = {70941, 71608}, [5] = {71604, 70945}, [7] = {71607, 70942}, [10] = {71605, 70943} }, -- Molten Giant Battleplate
    },
    [2] = {
      { [1] = {70948, 71524}, [3] = {70946, 71526}, [5] = {70950, 71522}, [7] = {71525, 70947}, [10] = {71523, 70949} }, -- Battlearmor of Immolation
      { [1] = {71514, 71065}, [3] = {71067, 71516}, [5] = {71063, 71512}, [7] = {71515, 71066}, [10] = {71513, 71064} }, -- Battleplate of Immolation
      { [1] = {71519, 71093}, [3] = {71521, 71095}, [5] = {71517, 71091}, [7] = {71520, 71094}, [10] = {71092, 71518} }, -- Regalia of Immolation
    },
    [3] = {
      { [1] = {71503, 71051}, [3] = {71505, 71053}, [5] = {71501, 71054}, [7] = {71052, 71504}, [10] = {71502, 71050} }, -- Flamewaker's Battlegear
    },
    [4] = {
      { [1] = {71539, 71047}, [3] = {71541, 71049}, [5] = {71537, 71045}, [7] = {71048, 71540}, [10] = {71046, 71538} }, -- Vestments of the Dark Phoenix
    },
    [5] = {
      { [1] = {71272, 71528}, [3] = {71531, 71275}, [5] = {71274, 71530}, [7] = {71273, 71529}, [10] = {71271, 71527} }, -- Vestments of the Cleansing Flame
      { [1] = {71277, 71533}, [3] = {71536, 71280}, [5] = {71535, 71279}, [7] = {71278, 71534}, [10] = {71532, 71276} }, -- Regalia of the Cleansing Flame
    },
    [6] = {
      { [1] = {71478, 71060}, [3] = {71480, 71062}, [5] = {71476, 71058}, [7] = {71479, 71061}, [10] = {71059, 71477} }, -- Gladiator's Set
      { [1] = {71483, 70954}, [3] = {71485, 70951}, [5] = {71481, 70955}, [7] = {71484, 70952}, [10] = {70953, 71482} }, -- Elementium Deathplate Battlearmor
    },
    [7] = {
      { [1] = {71293, 71554}, [3] = {71556, 71295}, [5] = {71552, 71291}, [7] = {71555, 71294}, [10] = {71553, 71292} }, -- Volcanic Regalia
      { [1] = {71549, 71303}, [3] = {71305, 71551}, [5] = {71547, 71301}, [7] = {71550, 71304}, [10] = {71548, 71302} }, -- Volcanic Battlegear
      { [1] = {71298, 71544}, [3] = {71546, 71300}, [5] = {71542, 71296}, [7] = {71545, 71299}, [10] = {71543, 71297} }, -- Volcanic Vestments
    },
    [8] = {
      { [1] = {71508, 71287}, [3] = {71511, 71290}, [5] = {71289, 71510}, [7] = {71288, 71509}, [10] = {71286, 71507} }, -- Firehawk Robes of Conflagration
    },
    [9] = {
      { [1] = {71595, 71282}, [3] = {71598, 71285}, [5] = {71284, 71597}, [7] = {71596, 71283}, [10] = {71281, 71594} }, -- Balespider's Burning Vestments
    },
    [11] = {
      { [1] = {71103, 71492}, [3] = {71495, 71106}, [5] = {71105, 71494}, [7] = {71104, 71493}, [10] = {71491, 71102} }, -- Obsidian Arborweave Vestments
      { [1] = {71108, 71497}, [3] = {71500, 71111}, [5] = {71110, 71499}, [7] = {71109, 71498}, [10] = {71496, 71107} }, -- Obsidian Arborweave Regalia
      { [1] = {71098, 71488}, [3] = {71101, 71490}, [5] = {71100, 71486}, [7] = {71489, 71099}, [10] = {71487, 71097} }, -- Obsidian Arborweave Battlegarb
    },
  },
  ["s9"] = {
    [1] = {
      { [1] = {60420, 70479, 72466, 70625, 73480, 73653, 65582, 64813, 64945, 70256}, [3] = {73651, 64943, 70627, 64815, 73478, 60422, 70477, 65580, 70258, 72468}, [5] = {72464, 70623, 73482, 73655, 65584, 70254, 60418, 64947, 64811, 70481}, [7] = {70257, 70478, 72467, 73652, 60421, 73479, 70626, 65581, 64944, 64814}, [10] = {70480, 73654, 72465, 73481, 70255, 60419, 70624, 64812, 65583, 64946} }, -- Gladiator's Battlegear
    },
    [2] = {
      { [1] = {60603, 64804, 64950, 70417, 70617, 73558, 73699, 70355, 65520, 72391}, [3] = {73556, 64948, 70415, 64806, 72393, 70357, 73697, 65518, 60605, 70619}, [5] = {70419, 64952, 70353, 70615, 72389, 73560, 65522, 64802, 60601, 73701}, [7] = {64805, 64949, 70416, 70618, 72392, 73557, 73698, 65519, 60604, 70356}, [10] = {64803, 64951, 70354, 70418, 70616, 73700, 73559, 72390, 60602, 65521} }, -- Gladiator's Redemption
      { [1] = {70487, 72380, 70650, 64935, 70251, 73706, 60415, 64845, 73569, 65590}, [3] = {73567, 70482, 73704, 70253, 64847, 70652, 60417, 72382, 64933, 65585}, [5] = {70249, 70489, 73708, 70648, 73571, 64937, 65592, 72378, 60413, 64843}, [7] = {73705, 64934, 70252, 70483, 73568, 70651, 72381, 64846, 65586, 60416}, [10] = {64936, 72379, 73707, 65591, 70649, 70488, 70250, 60414, 64844, 73570} }, -- Gladiator's Vindication
    },
    [3] = {
      { [1] = {65543, 64990, 73716, 70535, 70440, 64710, 70261, 60425, 72370, 73582}, [3] = {60427, 70263, 65537, 73580, 64988, 64712, 72372, 73714, 70537, 70434}, [5] = {72368, 73718, 60423, 70259, 70533, 64708, 73584, 64992, 65579, 70476}, [7] = {73581, 64989, 70262, 70536, 73715, 64711, 60426, 70435, 72371, 65538}, [10] = {64709, 60424, 64991, 72369, 73717, 65544, 70260, 73583, 70441, 70534} }, -- Gladiator's Pursuit
    },
    [4] = {
      { [1] = {64966, 72424, 70444, 70296, 65547, 73680, 73525, 60460, 64770, 70586}, [3] = {60462, 72426, 70298, 73678, 70588, 65545, 73523, 64772, 64964, 70442}, [5] = {64963, 64773, 65549, 60458, 70294, 70446, 72422, 73682, 73527, 70589}, [7] = {70297, 65546, 72425, 64771, 64965, 70587, 73524, 73679, 60461, 70443}, [10] = {70295, 72423, 60459, 64769, 65548, 70445, 73526, 73681, 64967, 70585} }, -- Gladiator's Vestments
    },
    [5] = {
      { [1] = {60469, 72401, 73693, 73548, 70305, 64796, 64956, 65555, 70452, 70609}, [3] = {64798, 70308, 70475, 73690, 72404, 70611, 60472, 65578, 64954, 73545}, [5] = {60471, 64799, 70307, 70450, 73691, 64953, 65553, 72403, 70612, 73546}, [7] = {64955, 70306, 70451, 73692, 73547, 65554, 64797, 70610, 72402, 60470}, [10] = {64957, 70304, 70453, 73694, 60468, 70608, 72400, 73549, 65556, 64795} }, -- Gladiator's Investiture
      { [1] = {64941, 72406, 70473, 60474, 70644, 73688, 64839, 65576, 73543, 70310}, [3] = {65573, 70646, 72409, 73685, 70313, 64841, 73540, 60477, 64939, 70470}, [5] = {65574, 64842, 70471, 72408, 73541, 73686, 70647, 70312, 64938, 60476}, [7] = {64940, 70645, 73542, 70472, 72407, 73687, 65575, 60475, 64840, 70311}, [10] = {70643, 64942, 65577, 73544, 70474, 72405, 73689, 64838, 70309, 60473} }, -- Gladiator's Raiment
    },
    [6] = {
      { [1] = {73618, 64980, 70246, 60410, 70492, 65595, 73740, 72334, 70560, 64737}, [3] = {64978, 70490, 72336, 73738, 70562, 60412, 65593, 70248, 73616, 64739}, [5] = {70494, 72332, 73620, 73742, 60408, 64982, 65597, 70244, 70558, 64735}, [7] = {64979, 73739, 70247, 72335, 73617, 70491, 60411, 65594, 64738, 70561}, [10] = {70245, 70493, 65596, 72333, 70559, 64981, 60409, 73741, 64736, 73619} }, -- Gladiator's Desecration
    },
    [7] = {
      { [1] = {65525, 65154, 70422, 72445, 73663, 60440, 70276, 73504, 70599, 64786}, [3] = {65152, 72447, 73502, 60442, 73661, 70420, 64788, 65523, 70601, 70278}, [5] = {70424, 73665, 65156, 73506, 64784, 65527, 70597, 72443, 60438, 70274}, [7] = {65153, 70421, 73662, 60441, 73503, 72446, 65524, 70277, 70600, 64787}, [10] = {70423, 70598, 73664, 70275, 60439, 72444, 64785, 65155, 65526, 73505} }, -- Gladiator's Thunderfist
      { [1] = {65569, 65149, 70266, 73515, 72434, 73673, 60430, 70466, 64829, 70634}, [3] = {60432, 70268, 73671, 65147, 65567, 72436, 73513, 70464, 70636, 64831}, [5] = {65151, 65536, 70433, 70632, 73517, 73675, 64827, 72432, 70264, 60428}, [7] = {65148, 70267, 70465, 70635, 73672, 64830, 65568, 72435, 60431, 73514}, [10] = {60429, 70265, 64828, 65150, 70467, 72433, 73674, 65570, 73516, 70633} }, -- Gladiator's Wartide
      { [1] = {70592, 70271, 70458, 60435, 72439, 64960, 73668, 64778, 65561, 73510}, [3] = {65559, 64958, 70594, 72441, 73508, 64780, 70273, 60437, 73666, 70456}, [5] = {65563, 64962, 70269, 60433, 70460, 72437, 64776, 73670, 70590, 73512}, [7] = {64959, 64779, 65560, 72440, 73667, 70593, 60436, 70457, 73509, 70272}, [10] = {70591, 72438, 73511, 73669, 65562, 64777, 64961, 60434, 70459, 70270} }, -- Gladiator's Earthshaker
    },
    [8] = {
      { [1] = {70462, 64931, 70656, 70300, 73575, 64854, 73712, 60464, 65565, 72374}, [3] = {73572, 60467, 70655, 70303, 72377, 64853, 65557, 70454, 73709, 64932}, [5] = {73710, 60466, 72376, 64856, 64929, 73573, 65558, 70455, 70658, 70302}, [7] = {64928, 73711, 65564, 70461, 70659, 72375, 60465, 64857, 73574, 70301}, [10] = {73713, 70657, 64930, 60463, 65566, 70299, 70463, 72373, 73576, 64855} }, -- Gladiator's Regalia
    },
    [9] = {
      { [1] = {64976, 70468, 73659, 73486, 60479, 65571, 70567, 72460, 64746, 70315}, [3] = {70318, 64977, 70566, 65528, 73656, 64745, 73483, 60482, 72463, 70425}, [5] = {64974, 64748, 65529, 70317, 70426, 70569, 73657, 73484, 60481, 72462}, [7] = {64973, 73658, 70427, 73485, 70316, 70570, 65530, 72461, 60480, 64749}, [10] = {64975, 73487, 73660, 70314, 70469, 60478, 72459, 65572, 70568, 64747} }, -- Gladiator's Felshroud
    },
    [11] = {
      { [1] = {73606, 64971, 70581, 64765, 70285, 70436, 72346, 73730, 65539, 60449}, [3] = {73727, 70584, 70288, 70430, 73603, 65533, 64768, 60452, 72349, 64968}, [5] = {64767, 70583, 73604, 70287, 70431, 72348, 60451, 65534, 64969, 73728}, [7] = {64766, 73605, 73729, 60450, 65535, 72347, 70432, 70582, 64970, 70286}, [10] = {73607, 73731, 64972, 60448, 65540, 70284, 70437, 72345, 70580, 64764} }, -- Gladiator's Refuge
      { [1] = {73736, 65588, 70280, 70551, 72338, 70485, 73614, 60444, 64728, 64986}, [3] = {73611, 73733, 60447, 64731, 65541, 70554, 72341, 70438, 70283, 64983}, [5] = {73734, 65542, 70282, 70439, 70553, 64730, 73612, 72340, 60446, 64984}, [7] = {64729, 70552, 73735, 64985, 73613, 70281, 72339, 70484, 60445, 65587}, [10] = {73615, 73737, 70486, 64727, 70550, 72337, 70279, 65589, 60443, 64987} }, -- Gladiator's Sanctuary
      { [1] = {70672, 60454, 65531, 73724, 70428, 73598, 72354, 70290, 64875, 64926}, [3] = {73721, 70675, 64878, 70447, 64923, 65550, 60457, 72357, 70293, 73595}, [5] = {73722, 65551, 70674, 60456, 72356, 70292, 70448, 73596, 64877, 64924}, [7] = {73723, 70449, 73597, 72355, 65552, 60455, 70291, 64876, 70673, 64925}, [10] = {70671, 64927, 73599, 65532, 64874, 70429, 72353, 60453, 70289, 73725} }, -- Gladiator's Wildhide
    },
  },
  [13] = {
    [1] = {
      { [1] = {78689, 76990, 78784}, [3] = {78734, 76992, 78829}, [5] = {78753, 76988, 78658}, [7] = {78705, 78800, 76991}, [10] = {78764, 78669, 76989} }, -- Colossal Dragonplate Armor
      { [1] = {78688, 78783, 76983}, [3] = {76987, 78735, 78830}, [5] = {78657, 76984, 78752}, [7] = {78706, 78801, 76986}, [10] = {78668, 76985, 78763} }, -- Colossal Dragonplate Battlegear
    },
    [2] = {
      { [1] = {78695, 77005, 78790}, [3] = {77007, 78840, 78745}, [5] = {78827, 77003, 78732}, [7] = {78715, 78810, 77006}, [10] = {78677, 78772, 77004} }, -- Armor of Radiant Glory
      { [1] = {78787, 76767, 78692}, [3] = {78841, 78746, 76769}, [5] = {76765, 78821, 78726}, [7] = {78812, 76768, 78717}, [10] = {78673, 78768, 76766} }, -- Regalia of Radiant Glory
      { [1] = {76876, 78788, 78693}, [3] = {78837, 78742, 76878}, [5] = {78727, 78822, 76874}, [7] = {76877, 78712, 78807}, [10] = {78770, 76875, 78675} }, -- Battleplate of Radiant Glory
    },
    [3] = {
      { [1] = {78793, 78698, 77030}, [3] = {77032, 78832, 78737}, [5] = {78756, 77028, 78661}, [7] = {78709, 77031, 78804}, [10] = {77029, 78674, 78769} }, -- Wyrmstalker Battlegear
    },
    [4] = {
      { [1] = {77025, 78794, 78699}, [3] = {77027, 78738, 78833}, [5] = {78759, 77023, 78664}, [7] = {78803, 77026, 78708}, [10] = {77024, 78774, 78679} }, -- Blackfang Battleweave
    },
    [5] = {
      { [1] = {76358, 78700, 78795}, [3] = {76361, 78747, 78842}, [5] = {76360, 78823, 78728}, [7] = {76359, 78719, 78814}, [10] = {76357, 78778, 78683} }, -- Vestments of Dying Light
      { [1] = {78798, 78703, 76347}, [3] = {76344, 78845, 78750}, [5] = {78826, 76345, 78731}, [7] = {76346, 78817, 78722}, [10] = {78777, 78682, 76348} }, -- Regalia of Dying Light
    },
    [6] = {
      { [1] = {76976, 78782, 78687}, [3] = {78831, 78736, 76978}, [5] = {78659, 76974, 78754}, [7] = {76977, 78802, 78707}, [10] = {78765, 78670, 76975} }, -- Necrotic Boneplate Battlegear
      { [1] = {78792, 78697, 77010}, [3] = {78846, 78751, 77012}, [5] = {77008, 78663, 78758}, [7] = {77011, 78811, 78716}, [10] = {78678, 77009, 78773} }, -- Necrotic Boneplate Armor
    },
    [7] = {
      { [1] = {77042, 78686, 78781}, [3] = {78828, 78733, 77044}, [5] = {77040, 78819, 78724}, [7] = {77043, 78704, 78799}, [10] = {77041, 78762, 78667} }, -- Spiritwalker's Battlegear
      { [1] = {78691, 76758, 78786}, [3] = {76760, 78739, 78834}, [5] = {76756, 78820, 78725}, [7] = {78813, 76759, 78718}, [10] = {78672, 78767, 76757} }, -- Spiritwalker's Vestments
      { [1] = {77037, 78685, 78780}, [3] = {78741, 78836, 77035}, [5] = {78818, 77039, 78723}, [7] = {77036, 78711, 78806}, [10] = {77038, 78666, 78761} }, -- Spiritwalker's Regalia
    },
    [8] = {
      { [1] = {78701, 76213, 78796}, [3] = {78843, 78748, 76216}, [5] = {78729, 76215, 78824}, [7] = {76214, 78720, 78815}, [10] = {76212, 78671, 78766} }, -- Time Lord's Regalia
    },
    [9] = {
      { [1] = {76342, 78797, 78702}, [3] = {78844, 76339, 78749}, [5] = {78825, 76340, 78730}, [7] = {78816, 76341, 78721}, [10] = {76343, 78681, 78776} }, -- Vestments of the Faceless Shroud
    },
    [11] = {
      { [1] = {78696, 78791, 77019}, [3] = {78839, 78744, 77022}, [5] = {78662, 77021, 78757}, [7] = {78809, 77020, 78714}, [10] = {77018, 78676, 78771} }, -- Deep Earth Regalia
      { [1] = {76750, 78785, 78690}, [3] = {78835, 76753, 78740}, [5] = {76752, 78660, 78755}, [7] = {76751, 78805, 78710}, [10] = {78775, 76749, 78680} }, -- Deep Earth Vestments
      { [1] = {78789, 77015, 78694}, [3] = {78838, 77017, 78743}, [5] = {78665, 77013, 78760}, [7] = {78808, 77016, 78713}, [10] = {78684, 78779, 77014} }, -- Deep Earth Battlegarb
    },
  },
  -- Dragonflight - Vault of the Incarnates
  [29] = {
    -- Item Slot IDs: 1 - Head, 3 - Shoulders, 5 - Chest, 7 - Legs, 10 - Hands
    -- Warrior
    [1]  = {[1] = {200426}, [3] = {200428}, [5] = {200423}, [7] = {200427}, [10] = {200425}},
    -- Paladin
    [2]  = {[1] = {200417}, [3] = {200419}, [5] = {200414}, [7] = {200418}, [10] = {200416}},
    -- Hunter
    [3]  = {[1] = {200390}, [3] = {200392}, [5] = {200387}, [7] = {200391}, [10] = {200389}},
    -- Rogue
    [4]  = {[1] = {200372}, [3] = {200374}, [5] = {200369}, [7] = {200373}, [10] = {200371}},
    -- Priest
    [5]  = {[1] = {200327}, [3] = {200329}, [5] = {200324}, [7] = {200328}, [10] = {200326}},
    -- Death Knight
    [6]  = {[1] = {200408}, [3] = {200410}, [5] = {200405}, [7] = {200409}, [10] = {200407}},
    -- Shaman
    [7]  = {[1] = {200399}, [3] = {200401}, [5] = {200396}, [7] = {200400}, [10] = {200398}},
    -- Mage
    [8]  = {[1] = {200318}, [3] = {200320}, [5] = {200315}, [7] = {200319}, [10] = {200317}},
    -- Warlock
    [9]  = {[1] = {200336}, [3] = {200338}, [5] = {200333}, [7] = {200337}, [10] = {200335}},
    -- Monk
    [10] = {[1] = {200363}, [3] = {200365}, [5] = {200360}, [7] = {200364}, [10] = {200362}},
    -- Druid
    [11] = {[1] = {200354}, [3] = {200356}, [5] = {200351}, [7] = {200355}, [10] = {200353}},
    -- Demon Hunter
    [12] = {[1] = {200345}, [3] = {200347}, [5] = {200342}, [7] = {200346}, [10] = {200344}},
    -- Evoker
    [13] = {[1] = {200381}, [3] = {200383}, [5] = {200378}, [7] = {200382}, [10] = {200380}}
  },
  -- Dragonflight - Aberrus, the Shadowed Crucible
  [30] = {
    -- Item Slot IDs: 1 - Head, 3 - Shoulders, 5 - Chest, 7 - Legs, 10 - Hands
    -- Warrior
    [1]  = {[1] = {202443}, [3] = {202441}, [5] = {202446}, [7] = {202442}, [10] = {202444}},
    -- Paladin
    [2]  = {[1] = {202452}, [3] = {202450}, [5] = {202455}, [7] = {202451}, [10] = {202453}},
    -- Hunter
    [3]  = {[1] = {202479}, [3] = {202477}, [5] = {202482}, [7] = {202478}, [10] = {202480}},
    -- Rogue
    [4]  = {[1] = {202497}, [3] = {202495}, [5] = {202500}, [7] = {202496}, [10] = {202498}},
    -- Priest
    [5]  = {[1] = {202542}, [3] = {202540}, [5] = {202545}, [7] = {202541}, [10] = {202543}},
    -- Death Knight
    [6]  = {[1] = {202461}, [3] = {202459}, [5] = {202464}, [7] = {202460}, [10] = {202462}},
    -- Shaman
    [7]  = {[1] = {202470}, [3] = {202468}, [5] = {202473}, [7] = {202469}, [10] = {202471}},
    -- Mage
    [8]  = {[1] = {202551}, [3] = {202549}, [5] = {202554}, [7] = {202550}, [10] = {202552}},
    -- Warlock
    [9]  = {[1] = {202533}, [3] = {202531}, [5] = {202536}, [7] = {202532}, [10] = {202534}},
    -- Monk
    [10] = {[1] = {202506}, [3] = {202504}, [5] = {202509}, [7] = {202505}, [10] = {202507}},
    -- Druid
    [11] = {[1] = {202515}, [3] = {202513}, [5] = {202518}, [7] = {202514}, [10] = {202516}},
    -- Demon Hunter
    [12] = {[1] = {202524}, [3] = {202522}, [5] = {202527}, [7] = {202523}, [10] = {202525}},
    -- Evoker
    [13] = {[1] = {202488}, [3] = {202486}, [5] = {202491}, [7] = {202487}, [10] = {202489}}
  },
  -- Dragonflight - Amirdrassil, the Dream's Hope
  [31] = {
    -- Item Slot IDs: 1 - Head, 3 - Shoulders, 5 - Chest, 7 - Legs, 10 - Hands
    -- Warrior
    [1]  = {[1] = {207182}, [3] = {207180}, [5] = {207185}, [7] = {207181}, [10] = {207183}},
    -- Paladin
    [2]  = {[1] = {207191}, [3] = {207189}, [5] = {207194}, [7] = {207190}, [10] = {207192}},
    -- Hunter
    [3]  = {[1] = {207218}, [3] = {207216}, [5] = {207221}, [7] = {207217}, [10] = {207219}},
    -- Rogue
    [4]  = {[1] = {207236}, [3] = {207234}, [5] = {207239}, [7] = {207235}, [10] = {207237}},
    -- Priest
    [5]  = {[1] = {207281}, [3] = {207279}, [5] = {207284}, [7] = {207280}, [10] = {207282}},
    -- Death Knight
    [6]  = {[1] = {207200}, [3] = {207198}, [5] = {207203}, [7] = {207199}, [10] = {207201}},
    -- Shaman
    [7]  = {[1] = {207209}, [3] = {207207}, [5] = {207212}, [7] = {207208}, [10] = {207210}},
    -- Mage
    [8]  = {[1] = {207290}, [3] = {207288}, [5] = {207293}, [7] = {207289}, [10] = {207291}},
    -- Warlock
    [9]  = {[1] = {207272}, [3] = {207270}, [5] = {207275}, [7] = {207271}, [10] = {207273}},
    -- Monk
    [10] = {[1] = {207245}, [3] = {207243}, [5] = {207248}, [7] = {207244}, [10] = {207246}},
    -- Druid
    [11] = {[1] = {207254}, [3] = {207252}, [5] = {207257}, [7] = {207253}, [10] = {207255}},
    -- Demon Hunter
    [12] = {[1] = {207263}, [3] = {207261}, [5] = {207266}, [7] = {207262}, [10] = {207264}},
    -- Evoker
    [13] = {[1] = {207227}, [3] = {207225}, [5] = {207230}, [7] = {207226}, [10] = {207228}}
  },
  -- Dragonflight - Season 4
  ["DFS4"] = {
    -- Item Slot IDs: 1 - Head, 3 - Shoulders, 5 - Chest, 7 - Legs, 10 - Hands
    -- Warrior
    [1]  = {[1] = {217218}, [3] = {217220}, [5] = {217216}, [7] = {217219}, [10] = {217217}},
    -- Paladin
    [2]  = {[1] = {217198}, [3] = {217200}, [5] = {217196}, [7] = {217199}, [10] = {217197}},
    -- Hunter
    [3]  = {[1] = {217183}, [3] = {217185}, [5] = {217181}, [7] = {217184}, [10] = {217182}},
    -- Rogue
    [4]  = {[1] = {217208}, [3] = {217210}, [5] = {217206}, [7] = {217209}, [10] = {217207}},
    -- Priest
    [5]  = {[1] = {217202}, [3] = {217204}, [5] = {217205}, [7] = {217203}, [10] = {217201}},
    -- Death Knight
    [6]  = {[1] = {217223}, [3] = {217225}, [5] = {217221}, [7] = {217224}, [10] = {217222}},
    -- Shaman
    [7]  = {[1] = {217238}, [3] = {217240}, [5] = {217236}, [7] = {217239}, [10] = {217237}},
    -- Mage
    [8]  = {[1] = {217232}, [3] = {217234}, [5] = {217235}, [7] = {217233}, [10] = {217231}},
    -- Warlock
    [9]  = {[1] = {217212}, [3] = {217214}, [5] = {217215}, [7] = {217213}, [10] = {217211}},
    -- Monk
    [10] = {[1] = {217188}, [3] = {217190}, [5] = {217186}, [7] = {217189}, [10] = {217187}},
    -- Druid
    [11] = {[1] = {217193}, [3] = {217195}, [5] = {217191}, [7] = {217194}, [10] = {217192}},
    -- Demon Hunter
    [12] = {[1] = {217228}, [3] = {217230}, [5] = {217226}, [7] = {217229}, [10] = {217227}},
    -- Evoker
    [13] = {[1] = {217178}, [3] = {217180}, [5] = {217176}, [7] = {217179}, [10] = {217177}}
  },
  ["TWW1"] = {
    -- Item Slot IDs: 1 - Head, 3 - Shoulders, 5 - Chest, 7 - Legs, 10 - Hands
    -- Warrior
    [1]  = {[1] = {211984}, [3] = {211982}, [5] = {211987}, [7] = {211983}, [10] = {211985}},
    -- Paladin
    [2]  = {[1] = {211993}, [3] = {211991}, [5] = {211996}, [7] = {211992}, [10] = {211994}},
    -- Hunter
    [3]  = {[1] = {212020}, [3] = {212018}, [5] = {212023}, [7] = {212019}, [10] = {212021}},
    -- Rogue
    [4]  = {[1] = {212038}, [3] = {212036}, [5] = {212041}, [7] = {212037}, [10] = {212039}},
    -- Priest
    [5]  = {[1] = {212083}, [3] = {212081}, [5] = {212086}, [7] = {212082}, [10] = {212084}},
    -- Death Knight
    [6]  = {[1] = {212002}, [3] = {212000}, [5] = {212005}, [7] = {212001}, [10] = {212003}},
    -- Shaman
    [7]  = {[1] = {212011}, [3] = {212009}, [5] = {212014}, [7] = {212010}, [10] = {212012}},
    -- Mage
    [8]  = {[1] = {212092}, [3] = {212090}, [5] = {212095}, [7] = {212091}, [10] = {212093}},
    -- Warlock
    [9]  = {[1] = {212074}, [3] = {212072}, [5] = {212077}, [7] = {212073}, [10] = {212075}},
    -- Monk
    [10] = {[1] = {212047}, [3] = {212045}, [5] = {212050}, [7] = {212046}, [10] = {212048}},
    -- Druid
    [11] = {[1] = {212056}, [3] = {212054}, [5] = {212059}, [7] = {212055}, [10] = {212057}},
    -- Demon Hunter
    [12] = {[1] = {212065}, [3] = {212063}, [5] = {212068}, [7] = {212064}, [10] = {212066}},
    -- Evoker
    [13] = {[1] = {212029}, [3] = {212027}, [5] = {212032}, [7] = {212028}, [10] = {212030}}
  },
}
--TODO: Add classic/cata support
local GladiatorBadges = {
  -- DF Badges
  201807, -- Crimson
  205708, -- Obsidian
  209343, -- Verdant
  216279, -- Draconic
  -- TWW Badges
  218713, -- Forged
}

-- Usable items that may not become active until an event or threshold.
-- Adding an item to this list forces it into the UseableItems table.
local UsableItemOverride = {
  -- Dragonflight
  [208321] = true, -- Iridal
}

-- Retrieve the current player's equipment.
function Player:GetEquipment()
  return Equipment
end

-- Retrieve the current player's usable items
function Player:GetOnUseItems()
  return UseableItems
end

-- Retrieve the current player's trinket items
function Player:GetTrinketItems()
  local Equip = Player:GetEquipment()
  local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
  local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)
  return Trinket1, Trinket2
end

-- Retrieve the current player's trinket data
function Player:GetTrinketData(OnUseExcludes)
  local Equip = Player:GetEquipment()
  local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
  local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)
  local Trinket1Spell = Trinket1:OnUseSpell()
  local Trinket2Spell = Trinket2:OnUseSpell()
  local Trinket1SpellID = Trinket1Spell and Trinket1Spell:ID() or 0
  local Trinket2SpellID = Trinket2Spell and Trinket2Spell:ID() or 0
  local Trinket1Range = (Trinket1Spell and Trinket1Spell.MaximumRange > 0 and Trinket1Spell.MaximumRange <= 100) and Trinket1Spell.MaximumRange or 100
  local Trinket2Range = (Trinket2Spell and Trinket2Spell.MaximumRange > 0 and Trinket2Spell.MaximumRange <= 100) and Trinket2Spell.MaximumRange or 100
  local Trinket1CastTime = Trinket1Spell and Trinket1Spell:CastTime() or 0
  local Trinket2CastTime = Trinket2Spell and Trinket2Spell:CastTime() or 0
  local Trinket1Usable = Trinket1:IsUsable()
  local Trinket2Usable = Trinket2:IsUsable()
  local T1Excluded = false
  local T2Excluded = false
  if OnUseExcludes then
    for _, Item in pairs(OnUseExcludes) do
      if Item and Trinket1:ID() == Item then
        T1Excluded = true
      end
      if Item and Trinket2:ID() == Item then
        T2Excluded = true
      end
    end
  end
  local T1 = {
    Object = Trinket1,
    ID = Trinket1:ID(),
    Level = Trinket1:Level(),
    Spell = Trinket1Spell,
    SpellID = Trinket1SpellID,
    Range = Trinket1Range,
    Usable = Trinket1Usable,
    CastTime = Trinket1CastTime,
    Cooldown = Trinket1:Cooldown(),
    Blacklisted = Player:IsItemBlacklisted(Trinket1) or T1Excluded
  }
  local T2 = {
    Object = Trinket2,
    ID = Trinket2:ID(),
    Level = Trinket2:Level(),
    Spell = Trinket2Spell,
    SpellID = Trinket2SpellID,
    Range = Trinket2Range,
    Usable = Trinket2Usable,
    CastTime = Trinket2CastTime,
    Cooldown = Trinket2:Cooldown(),
    Blacklisted = Player:IsItemBlacklisted(Trinket2) or T2Excluded
  }
  return T1, T2
end

-- Save the current player's equipment.
function Player:UpdateEquipment()
  wipe(Equipment)
  wipe(UseableItems)

  for i = 1, 19 do
    local ItemID = select(1, GetInventoryItemID("player", i))
    -- If there is an item in that slot
    if ItemID ~= nil then
      -- Equipment
      Equipment[i] = ItemID
      -- Useable Items
      local ItemObject
      if i == 13 or i == 14 then
        ItemObject = Item(ItemID, {i})
      else
        ItemObject = Item(ItemID)
      end
      if ItemObject:OnUseSpell() or UsableItemOverride[ItemID] then 
        table.insert(UseableItems, ItemObject)
      end
    end
  end

  -- Update tier sets worn
  local ClassID = Cache.Persistent.Player.Class[3]
  for TierNum, TierData in pairs(TierSets) do
    Cache.Persistent.TierSets[TierNum] = {["2pc"] = false, ["4pc"] = false}
    local Count = 0
    for SlotID, ItemIDs in pairs(TierData[ClassID]) do
      local EquippedItem = Equipment[SlotID]
      if EquippedItem then
        for _, PossibleItemID in ipairs(ItemIDs) do
          if EquippedItem == PossibleItemID then
            Count = Count + 1
            break
          end
        end
      end
    end
    if Count >= 2 then Cache.Persistent.TierSets[TierNum]["2pc"] = true end
    if Count >= 4 then Cache.Persistent.TierSets[TierNum]["4pc"] = true end
  end
  
  
  self:RegisterListenedItemSpells()
end

do
  -- Global Custom Items
  -- Note: Can still be overriden on a per-module basis by passing in to ExcludedItems
  -- TODO: Add classic/cata support
  local GenericItems = {
    ----- Generic items that we always want to exclude
    --- The War Within
    [215133] = true, -- Binding of Binding
    [218422] = true, -- Forged Aspirant's Medallion
    [218716] = true, -- Forged Gladiator's Medallion
    [218717] = true, -- Forged Gladiator's Sigil of Adaptation
    [219381] = true, -- Fate Weaver
    [219931] = true, -- Algari Competitor's Medallion
    -- TWW Engineering Epic Quality Wrists
    [221805] = true,
    [221806] = true,
    [221807] = true,
    [221808] = true,
    -- TWW Engineering Uncommon Quality Wrists
    [217155] = true,
    [217156] = true,
    [217157] = true,
    [217158] = true,
    --- Dragonflight
    [207783] = true, -- Cruel Dreamcarver
    [204388] = true, -- Draconic Cauterizing Magma
    [201962] = true, -- Heat of Primal Winter
    [203729] = true, -- Ominous Chromatic Essence
    [200563] = true, -- Primal Ritual Shell
    [193000] = true, -- Ring-Bound Hourglass
    [193757] = true, -- Ruby Whelp Shell
    [202612] = true, -- Screaming Black Dragonscale
    [209948] = true, -- Spring's Keeper
    [195220] = true, -- Uncanny Pocketwatch
    -- DF Engineering Epic Quality Wrists
    [198322] = true,
    [198327] = true,
    [198332] = true,
    [198333] = true,
  }

  -- TODO: Add classic/cata support
  local EngItems = {
    ----- Engineering items (only available to a player with Engineering) to exclude
    ----- Most tinkers are situational at best, so we'll exclude every item with a tinker slot
    --- The War Within
    -- Epic Quality Goggles
    [221801] = true,
    [221802] = true,
    [221803] = true,
    [221804] = true,
    -- Rare Quality Goggles
    [225642] = true,
    [225643] = true,
    [225644] = true,
    [225645] = true,
    -- Uncommon Quality Goggles
    [217151] = true,
    [217152] = true,
    [217153] = true,
    [217154] = true,
    --- Dragonflight
    -- Epic Quality Goggles
    [198323] = true,
    [198324] = true,
    [198325] = true,
    [198326] = true,
    -- Rare Quality Goggles
    [198328] = true,
    [198329] = true,
    [198330] = true,
    [198331] = true,
    -- Uncommon Quality Goggles
    [205278] = true,
    [205279] = true,
    [205280] = true,
    [205281] = true,
  }

  local CustomItems = {
    -- Shadowlands
    BottledFlayedwingToxin          = Item(178742, {13, 14}),
    -- Dragonflight
    GlobeofJaggedIce                = Item(193732, {13, 14}),
    TreemouthsFesteringSplinter     = Item(193652, {13, 14}),
    -- The War Within
    ConcoctionKissofDeath           = Item(215174, {13, 14}),
    KahetiEmblem                    = Item(225651, {13, 14}),
  }

  local CustomItemSpells = {
    -- Shadowlands
    FlayedwingToxinBuff             = Spell(345545),
    -- Dragonflight
    SkeweringColdDebuff             = Spell(388929),
    -- The War Within
    ConcoctionKissofDeathBuff       = Spell(435493),
    KahetiEmblemBuff                = Spell(455464),
  }

  local RangeOverrides = {
    [207172]                          = 10, -- Belor'relos, the Suncaller
  }

  -- Check if the trinket is coded as blacklisted by the user or not.
  local function IsUserItemBlacklisted(Item)
    if not Item then return false end

    local ItemID = Item:ID()
    if HL.GUISettings.General.Blacklist.ItemUserDefined[ItemID] then
      if type(HL.GUISettings.General.Blacklist.ItemUserDefined[ItemID]) == "boolean" then
        return true
      else
        return HL.GUISettings.General.Blacklist.ItemUserDefined[ItemID](Item)
      end
    end

    return false
  end

  -- Check if the trinket is coded as blacklisted either globally or by the user
  function Player:IsItemBlacklisted(Item)
    if IsUserItemBlacklisted(Item) or not Item:SlotIDs() then
      return true
    end

    local ItemID = Item:ID()
    local ItemSlot = Item:SlotIDs()[1]

    -- Exclude all tabards and shirts
    if ItemSlot == 19 or ItemSlot == 4 then return true end

    -- Shadowlands items being excluded with custom checks.
    if ItemID == CustomItems.BottledFlayedwingToxin:ID() then
      return Player:BuffUp(CustomItemSpells.FlayedwingToxinBuff)
    end

    -- Dragonflight items being excluded with custom checks.
    if ItemID == CustomItems.GlobeofJaggedIce:ID() then
      return Target:DebuffStack(CustomItemSpells.SkeweringColdDebuff) < 4
    end

    if ItemID == CustomItems.TreemouthsFesteringSplinter:ID() then
      return not (Player:IsTankingAoE(8) or Player:IsTanking(Target))
    end

    -- The War Within items being excluded with custom checks.
    if ItemID == CustomItems.ConcoctionKissofDeath:ID() then
      return Player:BuffUp(CustomItemSpells.ConcoctionKissofDeathBuff)
    end

    if ItemID == CustomItems.KahetiEmblem:ID() then
      return Player:BuffStack(CustomItemSpells.KahetiEmblemBuff) < 4 and not (Player:BuffUp(CustomItemSpells.KahetiEmblemBuff) and Player:BuffRemains(CustomItemSpells.KahetiEmblemBuff) < 3) or Player:BuffDown(CustomItemSpells.KahetiEmblemBuff)
    end

    -- Any generic items we always want to exclude from suggestions.
    if GenericItems[ItemID] then return true end

    -- Handle Engineering excludes.
    for _, profindex in pairs({GetProfessions()}) do
      local prof = GetProfessionInfo(profindex)
      if prof == "Engineering" then
        -- Hacky workaround for excluding Engineering cloak/waist tinkers.
        -- If possible, find a way to parse tinkers and handle this properly.
        if ItemSlot == 6 or ItemSlot == 15 then
          return true
        end
        -- Exclude specific Engineering items.
        if EngItems[ItemID] then return true end
      end
    end

    -- Return false by default
    return false
  end

  -- Return the trinket item of the first usable trinket that is not blacklisted or excluded
  function Player:GetUseableItems(ExcludedItems, slotID, excludeTrinkets)
    for _, Item in ipairs(UseableItems) do
      local ItemID = Item:ID()
      local IsExcluded = false

      -- Did we specify a slotID? If so, mark as excluded if this trinket isn't in that slot
      if slotID and Equipment[slotID] ~= ItemID then
        IsExcluded = true
      -- Exclude trinket items if excludeTrinkets is true
      elseif excludeTrinkets and (Equipment[13] == ItemID or Equipment[14] == ItemID) then
        IsExcluded = true
      -- Check if the trinket is ready, unless it's blacklisted
      elseif Item:IsReady() and not Player:IsItemBlacklisted(Item) then
        for i=1, #ExcludedItems do
          if ExcludedItems[i] == ItemID then
            IsExcluded = true
            break
          end
        end

        if not IsExcluded then
          local ItemSlot = Item:SlotIDs()[1]
          local ItemSpell = Item:OnUseSpell()
          local ItemRange = (ItemSpell and ItemSpell.MaximumRange > 0 and ItemSpell.MaximumRange <= 100) and ItemSpell.MaximumRange or 100
          if RangeOverrides[ItemID] then ItemRange = RangeOverrides[ItemID] end
          return Item, ItemSlot, ItemRange
        end
      end
    end

    return nil
  end
end

-- Check if a tier set bonus is equipped
-- TODO: Add classic/cata support
function Player:HasTier(Tier, Pieces)
  local DFS4Translate = {
    -- Warrior
    [1] = { [71] = 29, [72] = 30, [73] = 31 },
    -- Paladin
    [2] = { [66] = 29, [70] = 31 },
    -- Hunter
    [3] = { [253] = 31, [254] = 31, [255] = 29 },
    -- Rogue
    [4] = { [259] = 31, [260] = 31, [261] = 31 },
    -- Priest
    [5] = { [258] = 30 },
    -- Death Knight
    [6] = { [250] = 30, [251] = 30, [252] = 31 },
    -- Shaman
    [7] = { [262] = 31, [263] = 31 },
    -- Mage
    [8] = { [62] = 31, [63] = 30, [64] = 31 },
    -- Warlock
    [9] = { [265] = 31, [266] = 31, [267] = 29 },
    -- Monk
    [10] = { [268] = 31, [269] = 29 },
    -- Druid
    [11] = { [102] = 29, [103] = 31, [104] = 30 },
    -- Demon Hunter
    [12] = { [577] = 31, [581] = 31 },
    -- Evoker
    [13] = { [1467] = 30, [1473] = 31 }
  }
  local Class = Cache.Persistent.Player.Class[3]
  local Spec = Cache.Persistent.Player.Spec[1]
  if DFS4Translate[Class][Spec] and DFS4Translate[Class][Spec] == Tier then
    return Cache.Persistent.TierSets[Tier][Pieces.."pc"] or Cache.Persistent.TierSets["DFS4"][Pieces.."pc"]
  else
    return Cache.Persistent.TierSets[Tier][Pieces.."pc"]
  end
end

-- Check if a Gladiator's Badge is equipped
function Player:GladiatorsBadgeIsEquipped()
  local Trinket1, Trinket2 = Player:GetTrinketItems()
  for _, v in pairs(GladiatorBadges) do
    if Trinket1:ID() == v or Trinket2:ID() == v then
      return true
    end
  end
  return false
end
