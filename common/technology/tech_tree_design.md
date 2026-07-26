# Isekai/Xianxia Tech Tree Design

Three trees replace Production/Military/Society. Internal category keys are reused so all
engine features (tech spread modifiers, IG bonuses, UI tabs) keep working; only localization
changes the display names:

| Internal category | Displayed as | File |
|---|---|---|
| production | **Artifice** | 10_artifice.txt |
| military | **Alchemy** | 20_alchemy.txt |
| society | **Spiritualism** | 30_spiritualism.txt |

**Vanilla tech KEYS are preserved** wherever a tech survives (so buildings/PMs/laws/units keep
working); display names are re-themed in localization. Prerequisites are rewired so no tech ever
requires a tech from another tree.

## Removed technologies (goods removed: oil, rubber, automobiles, radios, tanks*, steamers)
pumpjacks, oil_turbine, rubber_mastication, vulcanization, plastics, combustion_engine,
compression_ignition, radio.
(*tank units are re-themed as Colossal War Automata using Automata/Magic Cores; the `mobile_armor`
tech survives as "Colossal War Automata".)

## New technologies
- homunculus_creation (Alchemy, Era 2): unlocks the Homunculus Factory government building.

## Goods key mapping (renames via localization, keys unchanged)
coal=Spirit Stones, lead=Mythril, fertilizer=Spirit Fertilizer, steel=Magic Cores,
engines=Automata, explosives=Reagents, opium=Health Potions, dye=Potions, fruit=Spirit Fruit,
wine=Spirit Wine, tobacco=Spirit Herbs, silk=Spirit Thread, aeroplanes=Airships,
small_arms=Enchanted Arms, artillery=War Automata, ammunition=Consumables,
telephones=Communication Orbs.
Removed goods: oil, rubber, automobiles, radios, tanks, steamers.

## Building mapping (keys kept, loc renamed)
synthetics_plants=Potion Factory, motor_industry=Automata Industries, steel_mills=Core Foundries,
artillery_foundries=War Automata Foundries, automotive_industry=Airship Works,
electrics_industry=Orb Atelier, power_plant=Mana Reactor, chemical_plants=Spirit Fertilizer Works,
banana_plantation=Spirit Orchard, silk_plantation=Spirit Livestock Ranch,
tobacco_plantation=Spirit Herb Plantation, vineyard_plantation=Spirit Vineyard,
whaling_station=Leviathan Hunting Station, munition_plants=Consumables Workshop,
arms_industry=Enchanted Arms Atelier.
Removed buildings: dye_plantation, opium_plantation, rubber_plantation, oil_rig.
New buildings: building_reagents_factory (Reagents), building_spirit_beast_hunting (meat +
spirit stones), building_homunculus_factory (government; boosts state birthrate = "creates pops").

## Region specialization (tradition tech, tech level)
- Isekai: Artifice (high)
- Demonland: Spiritualism/Alchemy (high)
- Desert: Alchemy (high)
- North: Artifice/Alchemy (mid)
- Beastland: Spiritualism/Artifice (low)
- Xianxia: Spiritualism (high)
- Western Plateau: Spiritualism (mid)
- Southern Isles: Spiritualism (mid)
- Murim: Spiritualism (mid)
- Eastern Isles: Spiritualism/Artifice (mid)
- Western Isles: Spiritualism/Alchemy (low)

Unresearchable `tradition_*` techs (40_traditions.txt) grant +25%/-25% (single) or
+15%/+15%/-35% (dual) research speed & tech spread per category.
Every country starts with universal basics (standing_army, gunsmithing, military_drill, enclosure,
manufacturies, urbanization, tech_bureaucracy, rationalism, distillation, currency_standards,
navigation) plus the full Era 1 of its specialty tree. All Era 1 techs have 0-1 in-tree
prerequisites, and Quinine (Alchemy) / Airships (`military_aviation`, Artifice Era 2) sit on short
1-prereq chains so every region can reach them.

## Buff spread (each tree gets companies / authority / prestige / construction)
- Companies: Artifice corporate_charters+corporate_management; Alchemy joint_stock_companies+
  investment? no - Alchemy joint_stock_companies+macroeconomics; Spiritualism investment_banks.
- Authority: Artifice central_planning; Alchemy nationalism+pan-nationalism; Spiritualism
  mass_communication+political_agitation+mass_propaganda.
- Prestige: Artifice steel_frame_buildings+zeppelins; Alchemy organized_sports; Spiritualism
  romanticism/realism/camera/film.
- Construction: Artifice urbanization/steel_frame_buildings/elevator/pneumatic_tools/arc_welding;
  Alchemy modern_sewerage/reinforced_concrete; Spiritualism urban_planning/paved_roads.
- Gov. administration PMs: Spiritualism central_archives; Alchemy identification_documents;
  Artifice central_planning+mass_surveillance.
- Law unlocks exist in all three trees (see files).
