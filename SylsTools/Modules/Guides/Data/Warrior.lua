-- Syl's Tools > Class Guides: Warrior
-- Written for classic-style (1-60) Warrior mechanics. If WoW Forever changes an
-- ability, update the text here; spell matching is by name so ranks don't matter.

local _, ns = ...
local G = ns.Guides

local CREDIT = "Guide written for classic-style Warrior mechanics. Spot something that changed in WoW Forever? Let us know."

---------------------------------------------------------------------------
-- Tank
---------------------------------------------------------------------------
G:Register({
    class = "WARRIOR", key = "tank", title = "Tank", subtitle = "Protection",
    role = "TANK",
    intro = "As the tank, your job is to make every enemy attack |cffffffffyou|r instead of your group, and to survive it. "
        .. "Enemies attack whoever has the most |cffffd100threat|r, and you build threat by hitting them with the right abilities. "
        .. "Warriors use |cffffd100rage|r instead of mana: you gain it by dealing and taking damage, so it's normal to start a fight "
        .. "with little rage and build up.",
    credit = CREDIT,
    sections = {
        {
            title = "Before the pull",
            entries = {
                { tip = true, text = "Wear a |cffffffffshield|r and a one-handed weapon. Several key tanking abilities need a shield, and it blocks a lot of damage." },
                { spell = 71, name = "Defensive Stance", level = 10,
                  text = "Your tanking stance: you take less damage and generate more threat. Stay in it while tanking. "
                      .. "It comes from a class quest around level 10 - ask your class trainer." },
                { spell = 6673, name = "Battle Shout",
                  text = "Buffs the attack power of you and your party. Cast it before every pull; it also gives a little threat on nearby enemies." },
                { spell = 2687, name = "Bloodrage",
                  text = "Gives you rage instantly (at the cost of a little health). Use it right before pulling so you start the fight with rage." },
                { tip = true, text = "Check that your healer has mana before you pull. A tank who pulls while the healer is drinking is a tank who dies." },
            },
        },
        {
            title = "Pulling",
            entries = {
                { tip = true, text = "Pull with a |cffffffffranged weapon|r (bow, gun or throwing weapon), then step back out of sight around a corner. "
                    .. "The enemies have to come to you and bunch up, so casters can't stay at range and you can hit them all." },
                { spell = 100, name = "Charge", stance = "Battle",
                  text = "Rushes you to an enemy and gives you rage. Only works in Battle Stance and out of combat. Fine for single enemies; "
                      .. "for groups, pulling with a ranged weapon is usually safer." },
            },
        },
        {
            title = "One enemy: what to press",
            intro = "Go down this list and use the first one that's ready:",
            entries = {
                { spell = 23922, name = "Shield Slam", talent = true,
                  text = "Big threat for its rage cost. Use it every time it's off cooldown. (Protection talent, needs a shield.)" },
                { spell = 6572, name = "Revenge", stance = "Defensive",
                  text = "Lights up after you block, dodge or parry. It's cheap and causes a lot of threat, so press it whenever it's available." },
                { spell = 7386, name = "Sunder Armor",
                  text = "Your main threat button. Put 5 stacks on your target, then keep using it as your 'filler' when nothing above is ready. "
                      .. "It also makes the enemy take more damage from your group." },
                { spell = 78, name = "Heroic Strike",
                  text = "Only when you have spare rage (roughly 40+). It replaces your next normal swing, so it's a way to spend extra rage, "
                      .. "not your main button." },
                { spell = 2565, name = "Shield Block", stance = "Defensive",
                  text = "Blocks the next attacks. Use it when a hard-hitting enemy is on you; blocking also makes Revenge available more often." },
            },
        },
        {
            title = "Several enemies",
            entries = {
                { spell = 1160, name = "Demoralizing Shout",
                  text = "Hits every enemy near you: they deal less damage, and you get threat on all of them. A great first button on a group." },
                { spell = 6343, name = "Thunder Clap", stance = "Battle",
                  text = "Damages and slows the attacks of nearby enemies. It needs Battle Stance, so it's most useful at low level before you "
                      .. "have Defensive Stance." },
                { spell = 845, name = "Cleave",
                  text = "Like Heroic Strike but hits two enemies. Use it instead of Heroic Strike when there are two or more enemies." },
                { tip = true, level = 10, text = "Press |cffffffffTab|r to switch targets and put a Sunder Armor or two on each enemy, "
                    .. "so none of them wander off to your healer." },
                { tip = true, text = "Mark the main target with a skull (right-click its portrait > Target Marker Icons) and ask your group "
                    .. "to attack that one first. Damage dealers attacking random targets is the #1 reason tanks lose enemies." },
            },
        },
        {
            title = "An enemy is attacking someone else",
            entries = {
                { spell = 355, name = "Taunt", stance = "Defensive",
                  text = "Target the enemy and Taunt: it's forced to attack you. Follow up straight away with Sunder Armor or Revenge so it stays on you." },
                { spell = 694, name = "Mocking Blow", stance = "Battle",
                  text = "A backup taunt for when Taunt is on cooldown. Needs Battle Stance." },
                { spell = 1161, name = "Challenging Shout",
                  text = "Makes every enemy nearby attack you for 6 seconds. Emergency only: it has a 10-minute cooldown." },
                { tip = true, text = "Losing an enemy for a moment is normal. Don't panic. Taunt it back, then build threat on it." },
            },
        },
        {
            title = "Interrupts & emergencies",
            entries = {
                { spell = 72, name = "Shield Bash",
                  text = "Interrupts a spell being cast. Use it on enemy heals and big damage spells. Needs a shield." },
                { spell = 676, name = "Disarm", stance = "Defensive",
                  text = "Takes away an enemy's weapon for a few seconds, which greatly reduces the damage of armed enemies." },
                { spell = 12975, name = "Last Stand", talent = true,
                  text = "Temporarily increases your maximum health. Use it when your health drops dangerously low." },
                { spell = 871, name = "Shield Wall", stance = "Defensive",
                  text = "Greatly reduces the damage you take for a few seconds. Use it when you're about to die; it has a long cooldown." },
            },
        },
    },
})

---------------------------------------------------------------------------
-- Damage / levelling
---------------------------------------------------------------------------
G:Register({
    class = "WARRIOR", key = "dps", title = "Damage & Levelling", subtitle = "Arms / Fury",
    role = "DAMAGE",
    intro = "Your goal is to deal as much damage as possible without pulling too many enemies at once. "
        .. "Warriors use |cffffd100rage|r: you gain it by hitting and getting hit, so fight one enemy at a time "
        .. "and use your rage as it builds. Most warriors level in |cffffffffBattle Stance|r with a two-handed weapon.",
    credit = CREDIT,
    sections = {
        {
            title = "Setup",
            entries = {
                { spell = 2457, name = "Battle Stance",
                  text = "Your default stance for questing. Charge, Overpower and other key abilities need it." },
                { spell = 6673, name = "Battle Shout",
                  text = "Increases your attack power. Keep it up at all times." },
                { tip = true, text = "Eat food after fights to recover health. Warriors have no healing spells, so resting is part of the routine." },
            },
        },
        {
            title = "Starting a fight",
            entries = {
                { spell = 100, name = "Charge", stance = "Battle",
                  text = "Open every fight with Charge: it closes the distance, briefly stuns the enemy, and gives you rage." },
                { spell = 772, name = "Rend",
                  text = "A bleed that deals damage over time. Worth using early on enemies that will live a while. "
                      .. "Some enemies (like elementals and mechanical ones) can't bleed." },
            },
        },
        {
            title = "What to press",
            intro = "Go down this list and use the first one that's ready:",
            entries = {
                { spell = 5308, name = "Execute",
                  text = "Massive damage, but only when the enemy is below 20% health. Becomes your top button when it's usable." },
                { spell = 12294, name = "Mortal Strike", talent = true,
                  text = "Arms' big hit. Use it on cooldown." },
                { spell = 23881, name = "Bloodthirst", talent = true,
                  text = "Fury's big hit; it also heals you a little. Use it on cooldown." },
                { spell = 7384, name = "Overpower", stance = "Battle",
                  text = "Lights up after the enemy dodges. It can't be blocked, dodged or parried, so press it when it's available." },
                { spell = 1680, name = "Whirlwind", stance = "Berserker",
                  text = "Hits up to four nearby enemies. Great when you're fighting several at once." },
                { spell = 78, name = "Heroic Strike",
                  text = "Spend extra rage here when you have more than you need for the abilities above." },
                { spell = 1464, name = "Slam",
                  text = "A strong hit, but it pauses your swings while you cast it. Optional at low level." },
            },
        },
        {
            title = "Fighting several enemies",
            entries = {
                { spell = 6343, name = "Thunder Clap", stance = "Battle",
                  text = "Damages and slows nearby enemies so they hit you less often." },
                { spell = 1160, name = "Demoralizing Shout",
                  text = "Nearby enemies deal less damage. Very helpful when you have two or more enemies on you." },
                { spell = 845, name = "Cleave",
                  text = "Use instead of Heroic Strike when two enemies are next to you." },
                { spell = 12292, name = "Sweeping Strikes", talent = true, stance = "Battle",
                  text = "Your next few attacks also hit a second enemy. Use it whenever two enemies are on you." },
            },
        },
        {
            title = "Staying alive",
            entries = {
                { spell = 1715, name = "Hamstring",
                  text = "Slows the enemy. Use it on humanoids that try to run away at low health, so they don't bring friends back." },
                { spell = 5246, name = "Intimidating Shout",
                  text = "Makes nearby enemies flee in fear. An escape button for when a fight goes wrong." },
                { spell = 20230, name = "Retaliation", stance = "Battle",
                  text = "Counter-attacks everything that hits you in melee for a short time. Strong against several enemies at once." },
                { spell = 18499, name = "Berserker Rage", stance = "Berserker",
                  text = "Breaks fear and makes you immune to it briefly, which is useful against enemies that fear you." },
                { tip = true, text = "If you're about to die, run before the enemy is too low to flee, or use a healing potion. A repair bill beats a long run back." },
            },
        },
    },
})
