-- Finanzamt – Steuer-Erfolge: werden aus den vorhandenen (gesyncten) Daten berechnet, je Konto.
-- Neu errungene Erfolge: Banner mit Animation, klickbarer Link im Chat, optional Meldung im Gildenchat.
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF
local UI = GS.UI

local G1, S1 = 10000, 100
local function icon(n) return "Interface\\Icons\\" .. n end
local function set(list) local t = {} for _, id in ipairs(list) do t[id] = true end return t end
-- Getränkesorten (Teilmengen von GS.ALCOHOL_ITEMS)
GS.BEER_ITEMS = set({ 2686, 2894, 3703, 2596, 12003, 18287, 19222, 21151 }) -- Donnerbräu, Rhapsodiemalz, Süderstade-Stout, Zwergenstarkbier, Dunkles Zwergenlager, Dunkelbräu, Billiges Bier, Winterbräu
GS.WINE_ITEMS = set({ 2723, 1941, 4595 })  -- Pinot Noir, Merlot, Dschungelrebenwein
GS.RUM_ITEMS = set({ 1939, 9260, 20709 })  -- Süßer Rum, Flüchtiger Rum, Rumsey Rum

---------------------------------------------------------------------------
-- Daten eines Kontos für die Erfolge
---------------------------------------------------------------------------
function GS:AchContext(main)
	local calc = self:Calc()
	local a = calc.accounts[main]
	if not a then return nil end
	local cur = calc.week
	local c = { a = a, cur = cur, main = main, income = 0, weeksData = 0, streak = 0, bestStreak = 0, maxDeposit = 0,
		boerse = 0, gew = 0, fuchs = 0, topZone = 0, rank1 = 0, goal = 0, alc = 0, dogWeeks = 0, mountWeeks = 0,
		zeroWeek = 0, comeback = 0, firstTax = 0 }
	local sorted = {}
	for w in pairs(a.weeks) do sorted[#sorted + 1] = w end
	table.sort(sorted)
	for _, w in ipairs(sorted) do
		local r = a.weeks[w]
		local inc = self:WeekIncome(r)
		c.income = c.income + inc
		if w < cur then
			c.weeksData = c.weeksData + 1
			if (r.ahNet or 0) > 0 and (r.ahNet or 0) > (r.loot or 0) then c.boerse = 1 end
			if (r.gew or 0) > 0 then c.gew = 1 end
			if (r.wkActual or 0) > math.max(0, r.pausch or 0) then c.fuchs = 1 end
			if inc == 0 then c.zeroWeek = 1 end
			if (r.total or 0) > 0 then
				c.firstTax = 1
				local rank, n = self:TaxRank(main, w)
				if rank == 1 and n >= 2 then c.rank1 = 1 end
			end
			-- höchste Steuerzone erreicht
			local T = self:GetEffective("tariff", w)
			local top
			for _, z in ipairs(T.zones or {}) do
				if (tonumber(z[2]) or 0) > 0 and (not top or z[1] > top) then top = z[1] end
			end
			if top and top > 0 and (r.taxable or 0) > top then c.topZone = 1 end
		end
	end
	-- pünktlich: in Wochen mit Daten am Wochenende nichts überfällig; die Serie reißt bei jedem Rückstand
	local od = a.overdue or {}
	local firstW = sorted[1]
	local wasOverdue = false
	if firstW then
		for x = firstW, cur - 1 do
			if (od[x] or 0) > 0 then
				c.streak = 0
				wasOverdue = true
			else
				if wasOverdue then c.comeback = 1 end
				if a.weeks[x] then
					c.streak = c.streak + 1
					if c.streak > c.bestStreak then c.bestStreak = c.streak end
				end
			end
		end
	end
	for _, b in ipairs(a.bookings or {}) do
		if b.kind == "D" and (b.amount or 0) > c.maxDeposit then c.maxDeposit = b.amount end
	end
	for _, goal in ipairs(self:Goals()) do
		local v = self:GoalProgress(goal)
		if (v or 0) >= goal.target then
			for w, r in pairs(a.weeks) do
				if w >= goal.week and w < cur and (r.total or 0) > 0 then c.goal = 1 end
			end
		end
	end
	local g = self:G()
	for _, ch in ipairs(a.chars) do
		local rep = g and g.reports[ch]
		for _, d in pairs(rep and rep.w or {}) do c.alc = c.alc + (tonumber(d.al) or 0) end
	end
	-- weitere Kennzahlen für die kleineren Erfolge
	c.lootWeekMax, c.quest, c.vendor, c.buyback, c.ahLoss, c.mat, c.small, c.underRadar, c.wk = 0, 0, 0, 0, 0, 0, 0, 0, 0
	c.evasionWeeks, c.evasionSum, c.penalty, c.waived, c.deferred = 0, 0, 0, 0, 0
	c.churchWeeks, c.alcWeeks, c.taxWeeks = 0, 0, 0
	c.incomeWeekMax, c.taxWeekMax = 0, 0
	for _, w in ipairs(sorted) do
		local r = a.weeks[w]
		c.lootWeekMax = math.max(c.lootWeekMax, r.loot or 0)
		c.quest = c.quest + (r.quest or 0)
		c.vendor = c.vendor + (r.vendorGross or r.vendor or 0)
		if (r.buyback or 0) > 0 then c.buyback = 1 end
		-- nur abgeschlossene Wochen: in der laufenden Woche steht man nach dem Einstellen (Anzahlung) immer kurz im Minus
		if w < cur then c.ahLoss = math.max(c.ahLoss, r.ahCarryOut or 0) end
		if (r.matCost or 0) > 0 then c.mat = 1 end
		c.wk = c.wk + (r.wkActual or 0)
		c.incomeWeekMax = math.max(c.incomeWeekMax, self:WeekIncome(r))
		c.taxWeekMax = math.max(c.taxWeekMax, r.total or 0)
		if (r.dog or 0) > 0 then c.dogWeeks = c.dogWeeks + 1 end
		if (r.mount or 0) > 0 then c.mountWeeks = c.mountWeeks + 1 end
		if (r.church or 0) > 0 then c.churchWeeks = c.churchWeeks + 1 end
		if (r.alc or 0) > 0 then c.alcWeeks = c.alcWeeks + 1 end
		if (r.total or 0) > 0 then c.taxWeeks = c.taxWeeks + 1 end
		if (r.evasion or 0) > 0 then
			c.evasionWeeks = c.evasionWeeks + 1
			c.evasionSum = c.evasionSum + r.evasion
		end
		if (r.penalty or 0) > 0 then c.penalty = 1 end
		if (r.waived or 0) > 0 then c.waived = 1 end
		if r.deferredUntil then c.deferred = 1 end
		if w < cur then
			if r.small then c.small = 1 end
			if self:WeekIncome(r) > 0 and (r.total or 0) == 0 and not r.small and (r.factor or 1) > 0 then c.underRadar = 1 end
		end
	end
	c.objAccepted, c.objRejected = 0, 0
	for _, o in ipairs(a.objections or {}) do
		if o.decision == "angenommen" then c.objAccepted = 1 elseif o.decision == "abgelehnt" then c.objRejected = 1 end
	end
	c.book = {}
	for _, b in ipairs(a.bookings or {}) do
		if b.kind then c.book[b.kind] = (c.book[b.kind] or 0) + 1 end
	end
	c.maxDays, c.maxPt = 0, 0
	for w in pairs(a.weeks) do
		local days, pt = self:AccountActivity(a, w)
		c.maxDays = math.max(c.maxDays, days)
		c.maxPt = math.max(c.maxPt, pt)
	end
	c.chars = #a.chars
	c.wealth = (self:AccountWealth(a))
	-- Getränke (je Sorte gezählt)
	c.beer, c.wine, c.rum, c.drinkKinds = 0, 0, 0, 0
	local kinds = {}
	for _, ch in ipairs(a.chars) do
		local rep = g and g.reports[ch]
		for _, d in pairs(rep and rep.w or {}) do
			for id, x in pairs(type(d.ai) == "table" and d.ai or {}) do
				id = tonumber(id)
				local n = type(x) == "table" and (tonumber(x[1]) or 0) or 0
				if id and n > 0 then
					kinds[id] = true
					if self.BEER_ITEMS[id] then c.beer = c.beer + n end
					if self.WINE_ITEMS[id] then c.wine = c.wine + n end
					if self.RUM_ITEMS[id] then c.rum = c.rum + n end
				end
			end
		end
	end
	for _ in pairs(kinds) do c.drinkKinds = c.drinkKinds + 1 end
	c.church = self:ChurchLeft(main, cur + 1) and 1 or 0
	c.objections = #(a.objections or {})
	c.interest = a.interestTotal or 0
	c.taxTotal = a.taxTotal or 0
	c.bal = a.bal or 0
	return c
end

---------------------------------------------------------------------------
-- Erfolge: v(c) = aktueller Wert, goal = Ziel; fmt = Darstellung des Werts (Geld oder Zahl)
---------------------------------------------------------------------------
local M = "money"
GS.ACHIEVEMENTS = {
	-- Zahlungsmoral
	{ id = "punkt1", cat = "Zahlungsmoral", name = "Saubere Weste", icon = icon("INV_Misc_PocketWatch_01"), goal = 1,
		desc = "Eine Steuerwoche abgeschlossen, ohne überfällig zu sein.", v = function(c) return c.bestStreak end },
	{ id = "punkt2", cat = "Zahlungsmoral", name = "Pünktlicher Zahler", icon = icon("INV_Misc_PocketWatch_01"), goal = 2,
		desc = "2 Steuerwochen in Folge nie überfällig gewesen.", v = function(c) return c.bestStreak end, unit = "Wochen" },
	{ id = "punkt4", cat = "Zahlungsmoral", name = "Zuverlässig", icon = icon("INV_Misc_PocketWatch_01"), goal = 4,
		desc = "4 Steuerwochen in Folge nie überfällig gewesen.", v = function(c) return c.bestStreak end, unit = "Wochen" },
	{ id = "punkt6", cat = "Zahlungsmoral", name = "Vorbildlich", icon = icon("INV_Misc_PocketWatch_01"), goal = 6,
		desc = "6 Steuerwochen in Folge nie überfällig gewesen.", v = function(c) return c.bestStreak end, unit = "Wochen" },
	{ id = "punkt10", cat = "Zahlungsmoral", name = "Musterschüler", icon = icon("INV_Misc_PocketWatch_01"), goal = 10,
		desc = "10 Steuerwochen in Folge nie überfällig gewesen.", v = function(c) return c.bestStreak end, unit = "Wochen" },
	{ id = "punkt25", cat = "Zahlungsmoral", name = "Liebling des Finanzamts", icon = icon("INV_Misc_PocketWatch_01"), goal = 25,
		desc = "25 Steuerwochen in Folge nie überfällig gewesen.", v = function(c) return c.bestStreak end, unit = "Wochen" },
	{ id = "vorkasse", cat = "Zahlungsmoral", name = "Vorkasse", icon = icon("INV_Box_01"), goal = G1, fmt = M,
		desc = "Ein Guthaben von mindestens 1 Gold auf dem Steuerkonto gehabt.", v = function(c) return math.max(0, c.bal) end },
	{ id = "spendier", cat = "Zahlungsmoral", name = "Spendierhose", icon = icon("INV_Misc_Coin_02"), goal = G1, fmt = M,
		desc = "Mindestens 1 Gold auf einmal in die Gildenbank eingezahlt.", v = function(c) return c.maxDeposit end },
	{ id = "spende10", cat = "Zahlungsmoral", name = "Großspender", icon = icon("INV_Misc_Coin_02"), goal = 10 * G1, fmt = M,
		desc = "Mindestens 10 Gold auf einmal in die Gildenbank eingezahlt.", v = function(c) return c.maxDeposit end },
	{ id = "reuig", cat = "Zahlungsmoral", name = "Reuiger Sünder", icon = icon("Spell_Holy_HolyBolt"), goal = 1,
		desc = "Einen überfälligen Rückstand komplett beglichen.", v = function(c) return c.comeback end },
	{ id = "saeumig", cat = "Zahlungsmoral", name = "Säumig", icon = icon("Spell_Nature_TimeStop"), goal = 1,
		desc = "Verzugszinsen gezahlt. Das Finanzamt vergisst nicht.", v = function(c) return c.interest > 0 and 1 or 0 end },
	-- Wirtschaft
	{ id = "erste", cat = "Wirtschaft", name = "Willkommen im System", icon = icon("INV_Misc_Note_01"), goal = 1,
		desc = "Die erste Steuer festgesetzt bekommen.", v = function(c) return c.firstTax end },
	{ id = "eink25", cat = "Wirtschaft", name = "Kleinunternehmer", icon = icon("INV_Misc_Coin_04"), goal = 25 * G1, fmt = M,
		desc = "Insgesamt 25 Gold Einkommen erzielt.", v = function(c) return c.income end },
	{ id = "eink100", cat = "Wirtschaft", name = "Mittelstand", icon = icon("INV_Misc_Coin_03"), goal = 100 * G1, fmt = M,
		desc = "Insgesamt 100 Gold Einkommen erzielt.", v = function(c) return c.income end },
	{ id = "eink500", cat = "Wirtschaft", name = "Konzern", icon = icon("INV_Misc_Coin_01"), goal = 500 * G1, fmt = M,
		desc = "Insgesamt 500 Gold Einkommen erzielt.", v = function(c) return c.income end },
	{ id = "eink1500", cat = "Wirtschaft", name = "Großkonzern", icon = icon("INV_Misc_Coin_01"), goal = 1500 * G1, fmt = M,
		desc = "Insgesamt 1500 Gold Einkommen erzielt.", v = function(c) return c.income end },
	{ id = "eink5000", cat = "Wirtschaft", name = "Weltkonzern", icon = icon("INV_Misc_Coin_01"), goal = 5000 * G1, fmt = M,
		desc = "Insgesamt 5000 Gold Einkommen erzielt.", v = function(c) return c.income end },
	{ id = "woche10", cat = "Wirtschaft", name = "Gute Woche", icon = icon("INV_Misc_Coin_04"), goal = 10 * G1, fmt = M,
		desc = "10 Gold Einkommen in einer Steuerwoche.", v = function(c) return c.incomeWeekMax end },
	{ id = "woche50", cat = "Wirtschaft", name = "Goldene Woche", icon = icon("INV_Misc_Coin_02"), goal = 50 * G1, fmt = M,
		desc = "50 Gold Einkommen in einer Steuerwoche.", v = function(c) return c.incomeWeekMax end },
	{ id = "woche100", cat = "Wirtschaft", name = "Rekordwoche", icon = icon("INV_Misc_Coin_01"), goal = 100 * G1, fmt = M,
		desc = "100 Gold Einkommen in einer Steuerwoche.", v = function(c) return c.incomeWeekMax end },
	{ id = "boerse", cat = "Wirtschaft", name = "Börsenhai", icon = icon("INV_Misc_Coin_05"), goal = 1,
		desc = "In einer Woche mehr AH-Gewinn als Loot gemacht.", v = function(c) return c.boerse end },
	{ id = "gewerbe", cat = "Wirtschaft", name = "Gewerbetreibender", icon = icon("Trade_BlackSmithing"), goal = 1,
		desc = "Zum ersten Mal Gewerbesteuer gezahlt.", v = function(c) return c.gew end },
	{ id = "fuchs", cat = "Wirtschaft", name = "Steuersparfuchs", icon = icon("Trade_Engineering"), goal = 1,
		desc = "In einer Woche mehr Werbungskosten abgesetzt als den Pauschbetrag.", v = function(c) return c.fuchs end },
	{ id = "spitze", cat = "Wirtschaft", name = "Spitzensteuersatz", icon = icon("INV_Crown_02"), goal = 1,
		desc = "Mit dem Einkommen einer Woche in der höchsten Steuerzone gelandet.", v = function(c) return c.topZone end },
	{ id = "steuer1", cat = "Wirtschaft", name = "Leistungsträger", icon = icon("INV_Misc_Bag_10"), goal = G1, fmt = M,
		desc = "Insgesamt 1 Gold Steuern gezahlt.", v = function(c) return c.taxTotal end },
	{ id = "steuer10", cat = "Wirtschaft", name = "Großer Steuerzahler", icon = icon("INV_Misc_Bag_10"), goal = 10 * G1, fmt = M,
		desc = "Insgesamt 10 Gold Steuern gezahlt.", v = function(c) return c.taxTotal end },
	{ id = "steuer50", cat = "Wirtschaft", name = "Finanzier der Gilde", icon = icon("INV_Misc_Bag_10"), goal = 50 * G1, fmt = M,
		desc = "Insgesamt 50 Gold Steuern gezahlt.", v = function(c) return c.taxTotal end },
	{ id = "steuer100", cat = "Wirtschaft", name = "Staatstragend", icon = icon("INV_Misc_Bag_10"), goal = 100 * G1, fmt = M,
		desc = "Insgesamt 100 Gold Steuern gezahlt.", v = function(c) return c.taxTotal end },
	{ id = "stwoche5", cat = "Wirtschaft", name = "Zur Kasse gebeten", icon = icon("INV_Misc_Bag_10"), goal = 5 * G1, fmt = M,
		desc = "5 Gold Steuer in einer Steuerwoche.", v = function(c) return c.taxWeekMax end },
	{ id = "stwoche20", cat = "Wirtschaft", name = "Spitzenverdiener", icon = icon("INV_Crown_02"), goal = 20 * G1, fmt = M,
		desc = "20 Gold Steuer in einer Steuerwoche. Das Finanzamt sagt danke.", v = function(c) return c.taxWeekMax end },
	-- Gilde
	{ id = "platz1", cat = "Gilde", name = "Stütze der Gesellschaft", icon = icon("INV_Crown_01"), goal = 1,
		desc = "In einer Woche der größte Steuerzahler der Gilde gewesen.", v = function(c) return c.rank1 end },
	{ id = "sparschwein", cat = "Gilde", name = "Sparschwein", icon = icon("INV_Misc_Bag_10"), goal = 1,
		desc = "Mit Steuern zu einem Sparziel beigetragen, das erreicht wurde.", v = function(c) return c.goal end },
	{ id = "treue2", cat = "Gilde", name = "Neu im Amt", icon = icon("INV_Misc_Book_11"), goal = 2,
		desc = "2 Wochen mit Finanzamt-Daten.", v = function(c) return c.weeksData end, unit = "Wochen" },
	{ id = "treue4", cat = "Gilde", name = "Stammkunde", icon = icon("INV_Misc_Book_11"), goal = 4,
		desc = "4 Wochen mit Finanzamt-Daten.", v = function(c) return c.weeksData end, unit = "Wochen" },
	{ id = "treue6", cat = "Gilde", name = "Alter Bekannter", icon = icon("INV_Misc_Book_11"), goal = 6,
		desc = "6 Wochen mit Finanzamt-Daten.", v = function(c) return c.weeksData end, unit = "Wochen" },
	{ id = "treue10", cat = "Gilde", name = "Treue Seele", icon = icon("INV_Misc_Book_11"), goal = 10,
		desc = "10 Wochen mit Finanzamt-Daten.", v = function(c) return c.weeksData end, unit = "Wochen" },
	{ id = "treue25", cat = "Gilde", name = "Urgestein", icon = icon("INV_Misc_Book_11"), goal = 25,
		desc = "25 Wochen mit Finanzamt-Daten.", v = function(c) return c.weeksData end, unit = "Wochen" },
	{ id = "treue52", cat = "Gilde", name = "Ein Jahr beim Amt", icon = icon("INV_Misc_Book_11"), goal = 52,
		desc = "52 Wochen mit Finanzamt-Daten.", v = function(c) return c.weeksData end, unit = "Wochen" },
	{ id = "steuer3", cat = "Gilde", name = "Fleißiger Steuerzahler", icon = icon("INV_Misc_Coin_03"), goal = 3,
		desc = "In 3 Wochen Steuern gezahlt.", v = function(c) return c.taxWeeks end, unit = "Wochen" },
	{ id = "steuer8", cat = "Gilde", name = "Säule des Staates", icon = icon("INV_Misc_Coin_03"), goal = 8,
		desc = "In 8 Wochen Steuern gezahlt.", v = function(c) return c.taxWeeks end, unit = "Wochen" },
	-- Augenzwinkernd
	{ id = "stammgast", cat = "Augenzwinkernd", name = "Stammgast", icon = icon("INV_Drink_04"), goal = G1, fmt = M,
		desc = "Für 1 Gold alkoholische Getränke gekauft. Prost!", v = function(c) return c.alc end },
	{ id = "hund1", cat = "Augenzwinkernd", name = "Bello", icon = icon("Ability_Hunter_Pet_Wolf"), goal = 1,
		desc = "Zum ersten Mal Hundesteuer gezahlt. Wer ist ein braver Steuerzahler?", v = function(c) return c.dogWeeks end },
	{ id = "hund3", cat = "Augenzwinkernd", name = "Hundefreund", icon = icon("Ability_Hunter_Pet_Wolf"), goal = 3,
		desc = "3 Wochen Hundesteuer gezahlt.", v = function(c) return c.dogWeeks end, unit = "Wochen" },
	{ id = "hund6", cat = "Augenzwinkernd", name = "Rudelführer", icon = icon("Ability_Hunter_Pet_Wolf"), goal = 6,
		desc = "6 Wochen Hundesteuer gezahlt.", v = function(c) return c.dogWeeks end, unit = "Wochen" },
	{ id = "reiten1", cat = "Augenzwinkernd", name = "Hoch zu Ross", icon = icon("Ability_Mount_RidingHorse"), goal = 1,
		desc = "Zum ersten Mal Reittiersteuer gezahlt.", v = function(c) return c.mountWeeks end },
	{ id = "reiten4", cat = "Augenzwinkernd", name = "Kavallerie", icon = icon("Ability_Mount_RidingHorse"), goal = 4,
		desc = "4 Wochen Reittiersteuer gezahlt.", v = function(c) return c.mountWeeks end, unit = "Wochen" },
	{ id = "kirche1", cat = "Augenzwinkernd", name = "Kirchgänger", icon = icon("Spell_Holy_HolyBolt"), goal = 1,
		desc = "Zum ersten Mal Kirchensteuer gezahlt. Amen.", v = function(c) return c.churchWeeks end },
	{ id = "kirche4", cat = "Augenzwinkernd", name = "Treues Gemeindemitglied", icon = icon("Spell_Holy_HolyBolt"), goal = 4,
		desc = "4 Wochen Kirchensteuer gezahlt.", v = function(c) return c.churchWeeks end, unit = "Wochen" },
	{ id = "alk3", cat = "Augenzwinkernd", name = "Wochenendtrinker", icon = icon("INV_Drink_04"), goal = 3,
		desc = "In 3 Wochen Alkoholsteuer gezahlt.", v = function(c) return c.alcWeeks end, unit = "Wochen" },
	{ id = "kirche", cat = "Augenzwinkernd", name = "Ausgetreten", icon = icon("Spell_Holy_HolyBolt"), goal = 1,
		desc = "Aus der Kirche ausgetreten. Die Kirchensteuer dankt nicht.", v = function(c) return c.church end },
	{ id = "einspruch1", cat = "Augenzwinkernd", name = "Widerspruch!", icon = icon("INV_Scroll_03"), goal = 1,
		desc = "Den ersten Einspruch gegen einen Steuerbescheid eingelegt.", v = function(c) return c.objections end },
	{ id = "querulant", cat = "Augenzwinkernd", name = "Querulant", icon = icon("INV_Scroll_03"), goal = 3,
		desc = "3 Einsprüche gegen den Steuerbescheid eingelegt.", v = function(c) return c.objections end, unit = "Einsprüche" },
	{ id = "nullrunde", cat = "Augenzwinkernd", name = "Ohne Fleiß kein Preis", icon = icon("INV_Misc_Bag_08"), goal = 1,
		desc = "Eine ganze Steuerwoche ohne einen Kupfer Einkommen.", v = function(c) return c.zeroWeek end },
	{ id = "bier1", cat = "Augenzwinkernd", name = "Feierabendbier", icon = icon("INV_Drink_05"), goal = 1,
		desc = "Ein Bier gekauft. Das Finanzamt trinkt mit (20 % Alkoholsteuer).", v = function(c) return c.beer end },
	{ id = "bier20", cat = "Augenzwinkernd", name = "Stammtisch", icon = icon("INV_Drink_05"), goal = 20,
		desc = "20 Bier gekauft.", v = function(c) return c.beer end, unit = "Bier" },
	{ id = "bier100", cat = "Augenzwinkernd", name = "Brauereibesitzer", icon = icon("INV_Drink_05"), goal = 100,
		desc = "100 Bier gekauft. Die Leber hat Einspruch eingelegt.", v = function(c) return c.beer end, unit = "Bier" },
	{ id = "wein", cat = "Augenzwinkernd", name = "Weinkenner", icon = icon("INV_Drink_03"), goal = 1,
		desc = "Eine Flasche Wein gekauft. Für die gehobenen Steuerzahler.", v = function(c) return c.wine end },
	{ id = "rum", cat = "Augenzwinkernd", name = "Pirat", icon = icon("INV_Drink_04"), goal = 1,
		desc = "Rum gekauft. Yo-ho-ho und eine Buddel voll Steuern.", v = function(c) return c.rum end },
	{ id = "kneipe", cat = "Augenzwinkernd", name = "Kneipentour", icon = icon("INV_Drink_04"), goal = 5,
		desc = "5 verschiedene alkoholische Getränke gekauft.", v = function(c) return c.drinkKinds end, unit = "Sorten" },
	{ id = "familie", cat = "Augenzwinkernd", name = "Großfamilie", icon = icon("INV_Misc_Head_Human_01"), goal = 4,
		desc = "Main und mindestens 3 Twinks auf einem Steuerkonto.", v = function(c) return c.chars end, unit = "Charaktere" },
	{ id = "reich50", cat = "Augenzwinkernd", name = "Sparbuch", icon = icon("INV_Misc_Coin_03"), goal = 50 * G1, fmt = M,
		desc = "50 Gold Vermögen auf allen Charakteren zusammen.", v = function(c) return c.wealth end },
	{ id = "reich250", cat = "Augenzwinkernd", name = "Wohlhabend", icon = icon("INV_Misc_Coin_02"), goal = 250 * G1, fmt = M,
		desc = "250 Gold Vermögen auf allen Charakteren zusammen.", v = function(c) return c.wealth end },
	{ id = "reich500", cat = "Augenzwinkernd", name = "Dagobert", icon = icon("INV_Misc_Coin_01"), goal = 500 * G1, fmt = M,
		desc = "500 Gold Vermögen. Zeit für ein Bad im Geldspeicher.", v = function(c) return c.wealth end },
	{ id = "reich1000", cat = "Augenzwinkernd", name = "Krösus", icon = icon("INV_Misc_Coin_01"), goal = 1000 * G1, fmt = M,
		desc = "1000 Gold Vermögen. Das Finanzamt beobachtet dich mit großem Interesse.", v = function(c) return c.wealth end },
	-- Hinterziehung und Verwaltung
	{ id = "hinterz1", cat = "Steuerakte", name = "Steuersünder", icon = icon("INV_Misc_Bag_09"), goal = 1,
		desc = "Gold eingenommen, während das Addon nicht lief. Es wurde nachversteuert.", v = function(c) return c.evasionWeeks end },
	{ id = "hinterz3", cat = "Steuerakte", name = "Wiederholungstäter", icon = icon("INV_Misc_Bag_09"), goal = 3,
		desc = "In 3 Wochen Gold ohne Addon eingenommen.", v = function(c) return c.evasionWeeks end, unit = "Wochen" },
	{ id = "hinterzG", cat = "Steuerakte", name = "Großer Fisch", icon = icon("INV_Misc_Fish_02"), goal = G1, fmt = M,
		desc = "Insgesamt 1 Gold ohne Addon eingenommen.", v = function(c) return c.evasionSum end },
	{ id = "hinterz10", cat = "Steuerakte", name = "Steueroase", icon = icon("INV_Misc_Fish_02"), goal = 10 * G1, fmt = M,
		desc = "Insgesamt 10 Gold ohne Addon eingenommen. Die Steuerfahndung ist informiert.", v = function(c) return c.evasionSum end },
	{ id = "zuschlag", cat = "Steuerakte", name = "Erwischt!", icon = icon("Spell_Holy_SealOfJustice"), goal = 1,
		desc = "Einen Hinterziehungszuschlag aufgebrummt bekommen.", v = function(c) return c.penalty end },
	{ id = "erlass", cat = "Steuerakte", name = "Gnade vor Recht", icon = icon("Spell_Holy_HolyBolt"), goal = 1,
		desc = "Ein Offizier hat dir eine Nachversteuerung erlassen.", v = function(c) return c.waived end },
	{ id = "stundung", cat = "Steuerakte", name = "Aufschub", icon = icon("INV_Misc_PocketWatch_02"), goal = 1,
		desc = "Eine Stundung bekommen.", v = function(c) return c.deferred end },
	{ id = "einspruchOk", cat = "Steuerakte", name = "Recht bekommen", icon = icon("INV_Scroll_03"), goal = 1,
		desc = "Ein Einspruch wurde angenommen.", v = function(c) return c.objAccepted end },
	{ id = "einspruchNo", cat = "Steuerakte", name = "Abgeblitzt", icon = icon("INV_Scroll_03"), goal = 1,
		desc = "Ein Einspruch wurde abgelehnt. Das Amt irrt nie.", v = function(c) return c.objRejected end },
	{ id = "korrigiert", cat = "Steuerakte", name = "Amtlich korrigiert", icon = icon("INV_Misc_Note_02"), goal = 1,
		desc = "Ein Offizier hat dein Konto per Korrekturbuchung berichtigt.", v = function(c) return c.book.C or 0 end },
	{ id = "kleinbetrag", cat = "Steuerakte", name = "Kleinvieh", icon = icon("INV_Misc_Coin_06"), goal = 1,
		desc = "Eine Wochensteuer entfiel, weil sie unter der Kleinbetragsgrenze lag.", v = function(c) return c.small end },
	{ id = "radar", cat = "Steuerakte", name = "Unter dem Radar", icon = icon("INV_Misc_Spyglass_02"), goal = 1,
		desc = "Eine Woche Einkommen gehabt, aber dank Freibetrag keine Steuer gezahlt.", v = function(c) return c.underRadar end },
	-- kleinere Wirtschaftserfolge
	{ id = "gold1", cat = "Wirtschaft", name = "Das erste Gold", icon = icon("INV_Misc_Coin_06"), goal = G1, fmt = M,
		desc = "Insgesamt 1 Gold Einkommen erzielt.", v = function(c) return c.income end },
	{ id = "schatz5", cat = "Wirtschaft", name = "Schatzsucher", icon = icon("INV_Box_02"), goal = 5 * G1, fmt = M,
		desc = "In einer Woche 5 Gold aus Beute eingesammelt.", v = function(c) return c.lootWeekMax end },
	{ id = "schatz20", cat = "Wirtschaft", name = "Drachenhort", icon = icon("INV_Box_02"), goal = 20 * G1, fmt = M,
		desc = "In einer Woche 20 Gold aus Beute eingesammelt.", v = function(c) return c.lootWeekMax end },
	{ id = "quest10", cat = "Wirtschaft", name = "Laufbursche", icon = icon("INV_Misc_Note_01"), goal = 10 * G1, fmt = M,
		desc = "Insgesamt 10 Gold mit Quests verdient.", v = function(c) return c.quest end },
	{ id = "quest50", cat = "Wirtschaft", name = "Held der Questgeber", icon = icon("INV_Misc_Note_01"), goal = 50 * G1, fmt = M,
		desc = "Insgesamt 50 Gold mit Quests verdient.", v = function(c) return c.quest end },
	{ id = "ramsch20", cat = "Wirtschaft", name = "Ramschhändler", icon = icon("INV_Misc_Bag_07"), goal = 20 * G1, fmt = M,
		desc = "Insgesamt 20 Gold beim Händler verkauft.", v = function(c) return c.vendor end },
	{ id = "ramsch100", cat = "Wirtschaft", name = "Trödelkönig", icon = icon("INV_Misc_Bag_07"), goal = 100 * G1, fmt = M,
		desc = "Insgesamt 100 Gold beim Händler verkauft.", v = function(c) return c.vendor end },
	{ id = "rueckkauf", cat = "Wirtschaft", name = "Doch nicht!", icon = icon("INV_Misc_Bag_07"), goal = 1,
		desc = "Etwas beim Händler zurückgekauft.", v = function(c) return c.buyback end },
	{ id = "verlust50", cat = "Wirtschaft", name = "Verlustvortrag", icon = icon("INV_Misc_Coin_05"), goal = 50 * S1, fmt = M,
		desc = "Eine Steuerwoche mit mindestens 50 Silber AH-Verlust abgeschlossen. Wird mit den Folgewochen verrechnet.", v = function(c) return c.ahLoss end },
	{ id = "handwerk", cat = "Wirtschaft", name = "Handwerkskunst", icon = icon("Trade_BlackSmithing"), goal = 1,
		desc = "Handwerkswaren gekauft und als Wareneinsatz abgesetzt.", v = function(c) return c.mat end },
	{ id = "wk5", cat = "Wirtschaft", name = "Belegsammler", icon = icon("INV_Misc_Note_02"), goal = 5 * G1, fmt = M,
		desc = "Insgesamt 5 Gold Werbungskosten erfasst.", v = function(c) return c.wk end },
	-- Gildenbank und Aktivität
	{ id = "einzahlung", cat = "Gilde", name = "Zahltag", icon = icon("INV_Misc_Coin_03"), goal = 1,
		desc = "Zum ersten Mal Gold in die Gildenbank eingezahlt.", v = function(c) return c.book.D or 0 end },
	{ id = "sachspende", cat = "Gilde", name = "Sachspende", icon = icon("INV_Box_01"), goal = 1,
		desc = "Ein Item in die Gildenbank gelegt.", v = function(c) return c.book.d or 0 end },
	{ id = "selbst", cat = "Gilde", name = "Selbstbedienung", icon = icon("INV_Box_01"), goal = 1,
		desc = "Ein Item aus der Gildenbank genommen.", v = function(c) return c.book.w or 0 end },
	{ id = "kasse", cat = "Gilde", name = "Griff in die Kasse", icon = icon("INV_Misc_Coin_02"), goal = 1,
		desc = "Gold aus der Gildenbank genommen.", v = function(c) return c.book.W or 0 end },
	{ id = "reparatur", cat = "Gilde", name = "Auf Gildenkosten", icon = icon("Trade_BlackSmithing"), goal = 1,
		desc = "Auf Kosten der Gildenbank repariert.", v = function(c) return c.book.R or 0 end },
	{ id = "tage3", cat = "Gilde", name = "Regelmäßig", icon = icon("INV_Misc_PocketWatch_01"), goal = 3,
		desc = "An 3 Tagen einer Steuerwoche online gewesen.", v = function(c) return c.maxDays end, unit = "Tage" },
	{ id = "tage5", cat = "Gilde", name = "Fast täglich", icon = icon("INV_Misc_PocketWatch_01"), goal = 5,
		desc = "An 5 Tagen einer Steuerwoche online gewesen.", v = function(c) return c.maxDays end, unit = "Tage" },
	{ id = "dauer", cat = "Gilde", name = "Dauergast", icon = icon("INV_Misc_PocketWatch_01"), goal = 7,
		desc = "An allen 7 Tagen einer Steuerwoche online gewesen.", v = function(c) return c.maxDays end, unit = "Tage" },
	{ id = "spiel2", cat = "Gilde", name = "Feierabendzocker", icon = icon("Ability_Rogue_Sprint"), goal = 2 * 3600,
		desc = "2 Stunden Spielzeit in einer Steuerwoche.", v = function(c) return c.maxPt end, unit = "Std.", fmt = "hours" },
	{ id = "spiel5", cat = "Gilde", name = "Vielspieler", icon = icon("Ability_Rogue_Sprint"), goal = 5 * 3600,
		desc = "5 Stunden Spielzeit in einer Steuerwoche.", v = function(c) return c.maxPt end, unit = "Std.", fmt = "hours" },
	{ id = "spiel10", cat = "Gilde", name = "Halbmarathon", icon = icon("Ability_Rogue_Sprint"), goal = 10 * 3600,
		desc = "10 Stunden Spielzeit in einer Steuerwoche.", v = function(c) return c.maxPt end, unit = "Std.", fmt = "hours" },
	{ id = "marathon", cat = "Gilde", name = "Marathon", icon = icon("Ability_Rogue_Sprint"), goal = 20 * 3600,
		desc = "20 Stunden Spielzeit in einer Steuerwoche.", v = function(c) return c.maxPt end, unit = "Std.", fmt = "hours" },
	{ id = "spiel40", cat = "Gilde", name = "40-Stunden-Woche", icon = icon("INV_Misc_PocketWatch_02"), goal = 40 * 3600,
		desc = "40 Stunden Spielzeit in einer Steuerwoche. Ein Vollzeitjob, nur ohne Gehalt.", v = function(c) return c.maxPt end, unit = "Std.", fmt = "hours" },
}
-- nach Kategorie ordnen (innerhalb der Kategorie bleibt die Reihenfolge der Liste)
GS.ACH_CATS = { "Zahlungsmoral", "Wirtschaft", "Gilde", "Steuerakte", "Augenzwinkernd" }
do
	local rank = {}
	for i, cat in ipairs(GS.ACH_CATS) do rank[cat] = i end
	for i, d in ipairs(GS.ACHIEVEMENTS) do d._i = i end
	table.sort(GS.ACHIEVEMENTS, function(x, y)
		local rx, ry = rank[x.cat] or 99, rank[y.cat] or 99
		if rx ~= ry then return rx < ry end
		return x._i < y._i
	end)
end
GS.ACH_BY_ID = {}
for _, d in ipairs(GS.ACHIEVEMENTS) do GS.ACH_BY_ID[d.id] = d end

-- Anzeige in der aktiven Sprache (die Definitionen bleiben deutsch, sie werden beim Laden ausgewertet)
function GS:AchName(def) return def and L[def.name] or "?" end
function GS:AchDesc(def) return def and L[def.desc] or "" end
function GS:AchCat(cat) return L[cat] end

function GS:AchValueText(def, v)
	if def.fmt == M then return self:FormatMoney(math.floor(v or 0), true) end
	if def.fmt == "hours" then return tostring(math.floor((v or 0) / 3600)) end
	return tostring(math.floor(v or 0))
end

-- Stand aller Erfolge eines Kontos: { def, done, value, seen (Zeitpunkt, nur eigenes Konto) }
function GS:AchievementStates(main)
	local c = self:AchContext(main)
	if not c then return {} end
	local g = self:G()
	local seen = g and g.achSeen and g.achSeen[main] or {}
	local out = {}
	for _, def in ipairs(self.ACHIEVEMENTS) do
		local ok, v = pcall(def.v, c)
		v = ok and tonumber(v) or 0
		local done = v >= def.goal or seen[def.id] ~= nil -- einmal errungen bleibt errungen
		out[#out + 1] = { def = def, done = done, value = v, seen = seen[def.id] }
	end
	return out
end

-- Begründung für die Anzeige: „10 / 10 Wochen“ bzw. „52g / 50g“
function GS:AchProgressText(s)
	local def = s.def
	if def.goal == 1 and def.fmt ~= M then return s.done and L["erreicht"] or L["offen"] end
	local unit = def.unit and (" " .. L[def.unit]) or ""
	return self:AchValueText(def, math.max(0, s.value)) .. " / " .. self:AchValueText(def, def.goal) .. unit
end

---------------------------------------------------------------------------
-- Gildenchat-Meldungen (Offiziere schalten für die ganze Gilde)
---------------------------------------------------------------------------
function GS:AchChatEnabled()
	local list = self:SortedADM("ACHCHAT")
	local last = list[#list]
	return last and last.d and last.d.on and true or false
end

function GS:SetAchChat(on)
	return self:CreateADM("ACHCHAT", { on = on and true or false })
end

---------------------------------------------------------------------------
-- Chat-Link: „garrmission“-Links lässt der Server durch (wie bei WeakAuras); mit Addon klickbar
---------------------------------------------------------------------------
-- Klickbarer Link (nur für die lokale Anzeige; im Chat wird reiner Text gesendet und beim Empfänger umgewandelt).
-- Der Erfolg steckt im sichtbaren Text „[Erfolg: Name]“, der Absender kommt aus der Chatzeile.
function GS:AchLink(id)
	local def = self.ACH_BY_ID[id]
	local name = def and self:AchName(def) or id
	return "|Hgarrmission:finanzamt|h|cffffd100" .. LF("[Erfolg: %s]", name) .. "|r|h"
end

-- Text zum Senden/Einfügen in den Chat (ohne Steuercodes; Empfänger mit Addon sehen einen Link)
-- Gesendet wird in der Sprache des Absenders; Empfänger erkennen beide Sprachen.
function GS:AchChatText(id)
	local def = self.ACH_BY_ID[id]
	return LF("[Erfolg: %s]", def and self:AchName(def) or id)
end

-- Erfolg zu einem Namen (deutsch oder englisch)
function GS:AchByName(name)
	for _, d in ipairs(self.ACHIEVEMENTS) do
		if d.name == name or self:LangText(d.name, "en") == name then return d end
	end
end

-- Präfixe im Chattext (alle Sprachen): „[Erfolg: Name]“ / „[Achievement: Name]“
local ACH_PREFIX = { Erfolg = true, Achievement = true }
local function achNameIn(text)
	if type(text) ~= "string" then return nil end
	for pre, name in text:gmatch("%[(%a+): (.-)%]") do
		if ACH_PREFIX[pre] then return name end
	end
end

-- Erfolge im Chat: gesendet wird reiner Text „[Erfolg: Name]“ (Steuercodes lehnt der Client beim Senden ab).
-- Beim Anzeigen macht das Addon daraus einen klickbaren Link – nur für echte Erfolgsnamen – und merkt sich den Absender.
-- Absender werden unter dem deutschen Namen (def.name) gemerkt, damit beide Sprachen zusammenpassen.
local achSenders = {}
function GS:LinkifyAchText(msg, author)
	if type(msg) ~= "string" or not (msg:find("[Erfolg: ", 1, true) or msg:find("[Achievement: ", 1, true)) then return msg, false end
	local changed = false
	local out = msg:gsub("%[(%a+): ([^%]|]-)%]", function(pre, name)
		if not ACH_PREFIX[pre] then return nil end
		local def = self:AchByName(name)
		if not def then return nil end
		changed = true
		if author then achSenders[def.name] = { who = (author:gsub("%-.*$", "")), t = self:Now() } end
		return self:AchLink(def.id)
	end)
	return out, changed
end
local function chatFilter(_, _, msg, author, ...)
	local out, changed = GS:LinkifyAchText(msg, author)
	if changed then return false, out, author, ... end
	return false
end
if ChatFrame_AddMessageEventFilter then
	for _, ev in ipairs({ "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_SAY" }) do
		ChatFrame_AddMessageEventFilter(ev, chatFilter)
	end
end
GS._achSenders = achSenders

function GS:ShowAchTooltip(id, who, t)
	local tip = ItemRefTooltip
	if not tip then return end
	local def = self.ACH_BY_ID[id]
	if ShowUIPanel then ShowUIPanel(tip) end
	if not tip:IsShown() then tip:SetOwner(UIParent, "ANCHOR_PRESERVE") end
	tip:ClearLines()
	if not def then
		tip:AddLine(L["Unbekannter Finanzamt-Erfolg"], 1, 0.82, 0)
		tip:AddLine(L["Bitte das Addon aktualisieren."], 1, 1, 1, true)
		tip:Show()
		return
	end
	tip:AddLine("|T" .. def.icon .. ":22:22|t " .. self:AchName(def), 1, 0.82, 0)
	tip:AddLine(self:AchDesc(def), 1, 1, 1, true)
	tip:AddLine(" ")
	if who and who ~= "?" then
		local when = tonumber(t) or 0
		tip:AddLine(when > 0 and LF("Errungen von %s am %s", who, date("%d.%m.%Y", when)) or LF("Errungen von %s", who), 0.6, 1, 0.6)
	end
	-- Begründung aus den eigenen (gesyncten) Daten, falls das Konto bekannt ist
	if who and self:G() then
		local main = self:AccountOf(who)
		for _, s in ipairs(self:AchievementStates(main)) do
			if s.def.id == id then
				tip:AddLine(LF("Fortschritt: %s", self:AchProgressText(s)), 0.8, 0.8, 0.8)
				break
			end
		end
	end
	tip:AddLine(LF("Finanzamt-Erfolg · %s", self:AchCat(def.cat)), 0.5, 0.5, 0.5)
	tip:Show()
end

function GS:HandleAchLink(link, text)
	if type(link) ~= "string" then return false end
	-- älteres Format mit Daten im Link
	local id, who, t = link:match("^garrmission:finanzamt:ach:([^:]+):([^:]*):(%d+)")
	if id then
		self:ShowAchTooltip(id, who, t)
		return true
	end
	if link ~= "garrmission:finanzamt" then return false end
	local name = achNameIn(text)
	local def = name and self:AchByName(name)
	local snd = name and (achSenders[def and def.name or name] or achSenders[name])
	self:ShowAchTooltip(def and def.id or (name or "?"), snd and snd.who, snd and snd.t)
	return true
end

if hooksecurefunc and SetItemRef then
	hooksecurefunc("SetItemRef", function(link, text) GS:HandleAchLink(link, text) end)
end

-- Erfolg in den Gildenchat schicken; Rückgabe ok, Fehlertext
function GS:SendAchChat(def, prefix)
	if not SendChatMessage then return false, L["SendChatMessage fehlt"] end
	if IsInGuild and not IsInGuild() then return false, L["nicht in einer Gilde"] end
	local msg = (prefix or L["Neuer Finanzamt-Erfolg: "]) .. self:AchChatText(def.id) -- reiner Text, ohne Steuercodes
	local ok, err = pcall(SendChatMessage, msg, "GUILD")
	if self.debug then
		self:Print(ok and LF("Gildenchat gesendet: %s", msg) or LF("Gildenchat Fehler: %s: %s", tostring(err), msg))
	end
	return ok, err
end

-- echter Test im Gildenchat: /gst erfolgchat senden
function GS:TestAchChatSend()
	local list = self.ACHIEVEMENTS
	local def = list[math.random(1, #list)]
	self:Print(LF("Gildenchat-Meldungen sind %s. Sende Testmeldung in den Gildenchat ...",
		self:AchChatEnabled() and L["|cff40ff40an|r"] or L["|cffff8040aus|r"]))
	local ok, err = self:SendAchChat(def, L["Finanzamt-Test: "])
	if not ok then self:Print(LF("|cffff4040Senden fehlgeschlagen:|r %s", tostring(err))) end
	return ok
end

-- Gildenchat-Meldung nur lokal anzeigen (so, wie sie im Gildenchat aussähe): /gst erfolgchat
function GS:TestAchChat()
	local list = self.ACHIEVEMENTS
	local def = list[math.random(1, #list)]
	local msg = L["Neuer Finanzamt-Erfolg: "] .. self:AchLink(def.id, self.player, self:Now())
	local info = ChatTypeInfo and ChatTypeInfo.GUILD
	local r, g, b = (info and info.r) or 0.25, (info and info.g) or 1, (info and info.b) or 0.25
	local who = "|Hplayer:" .. self.player .. "|h[" .. self.player .. "]|h"
	local line = L["[Gilde]"] .. " " .. who .. ": " .. msg .. " " .. L["|cff888888(Test, nur für dich sichtbar)|r"]
	if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line, r, g, b) else print(line) end
	return line
end

---------------------------------------------------------------------------
-- Banner mit Animation (eigene Gestaltung im Stil eines Erfolgs)
---------------------------------------------------------------------------
local toast, queue = nil, {}
GS.ACH_SINGLE_MAX = 5 -- bis zu so vielen neuen Erfolgen auf einmal: je ein eigenes Banner
local IN, SHINE0, SHINE1, HOLD, OUT = 0.35, 0.45, 1.25, 5.5, 0.6

local function createToast()
	local f = CreateFrame("Button", "FinanzamtAchievementToast", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(330, 82)
	f:SetFrameStrata("HIGH")
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
			tile = true, tileSize = 32, edgeSize = 24,
			insets = { left = 6, right = 6, top = 6, bottom = 6 },
		})
	end
	if f.SetClipsChildren then f:SetClipsChildren(true) end
	-- schlichter Goldrahmen: Gold, schwarzer Innenrand, dann das Icon
	f.ring = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.ring:SetSize(50, 50)
	f.ring:SetPoint("LEFT", 14, 0)
	f.ring:SetTexture("Interface\\Buttons\\WHITE8X8")
	f.ring:SetVertexColor(0.85, 0.68, 0.25)
	f.iconBg = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	f.iconBg:SetSize(46, 46)
	f.iconBg:SetPoint("CENTER", f.ring, "CENTER", 0, 0)
	f.iconBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	f.iconBg:SetVertexColor(0, 0, 0)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(44, 44)
	f.icon:SetPoint("CENTER", f.ring, "CENTER", 0, 0)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.head:SetPoint("TOPLEFT", 74, -14)
	f.head:SetText(L["Erfolg errungen"])
	f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	f.name:SetPoint("TOPLEFT", 74, -30)
	f.name:SetWidth(240)
	f.name:SetJustifyH("LEFT")
	f.desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.desc:SetPoint("TOPLEFT", 74, -52)
	f.desc:SetWidth(240)
	f.desc:SetJustifyH("LEFT")
	f.desc:SetTextColor(0.8, 0.8, 0.8)
	f.shine = f:CreateTexture(nil, "OVERLAY")
	f.shine:SetTexture("Interface\\Buttons\\WHITE8X8")
	f.shine:SetSize(36, 74)
	if f.shine.SetBlendMode then f.shine:SetBlendMode("ADD") end
	f.shine:SetVertexColor(1, 0.9, 0.6)
	f.shine:SetAlpha(0)
	-- verschiebbar; Position bleibt gespeichert
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetCenter()
		if x and y then GS.db.achPos = { x = x, y = y } end
	end)
	f:SetScript("OnClick", function(self)
		if self.cur and self.cur.id and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
			ChatEdit_InsertLink(GS:AchChatText(self.cur.id))
			return
		end
		if UI and UI.ShowAchievements then UI.ShowAchievements() end
		self.t = HOLD -- ausblenden
	end)
	f:Hide()
	f:SetScript("OnUpdate", function(self, el)
		if not (self.IsMouseOver and self:IsMouseOver() and self.t > IN and self.t < HOLD) then self.t = self.t + (el or 0) end
		local t = self.t
		local alpha, dy = 1, 0
		if t < IN then
			local p = t / IN
			alpha, dy = p, 24 * (1 - p)
		elseif t > HOLD then
			alpha = math.max(0, 1 - (t - HOLD) / OUT)
		end
		self:SetAlpha(alpha)
		self:ClearAllPoints()
		local pos = GS.db.achPos
		if pos then self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y + dy)
		else self:SetPoint("TOP", UIParent, "TOP", 0, -140 + dy) end
		-- Glanzstreifen läuft einmal über das Banner
		if t >= SHINE0 and t <= SHINE1 then
			local p = (t - SHINE0) / (SHINE1 - SHINE0)
			self.shine:ClearAllPoints()
			self.shine:SetPoint("LEFT", self, "LEFT", -36 + p * 366, 0)
			self.shine:SetAlpha(0.45 * math.sin(p * math.pi))
		else
			self.shine:SetAlpha(0)
		end
		if t > HOLD + OUT then
			self:Hide()
			GS:NextAchToast()
		end
	end)
	return f
end

local function playSound()
	if not PlaySound then return end
	local ok, willPlay = pcall(PlaySound, 12891, "Master") -- Erfolgssound, falls der Client ihn hat
	if not (ok and willPlay) then
		local lvl = SOUNDKIT and SOUNDKIT.LEVELUPSOUND or 888
		pcall(PlaySound, lvl, "Master")
	end
end

function GS:NextAchToast()
	if toast and toast:IsShown() then return end
	local item = table.remove(queue, 1)
	if not item then return end
	if InCombatLockdown and InCombatLockdown() then
		table.insert(queue, 1, item)
		C_Timer.After(3, function() GS:NextAchToast() end)
		return
	end
	toast = toast or createToast()
	toast.cur = item
	if item.summary then
		toast.icon:SetTexture(icon("INV_Misc_Coin_01"))
		toast.head:SetText(L["Erfolge errungen"])
		toast.name:SetText(LF("%d Finanzamt-Erfolge", item.summary))
		toast.desc:SetText(L["Klicken für die Liste unter Mein Konto"])
	else
		local def = self.ACH_BY_ID[item.id]
		toast.icon:SetTexture(def.icon)
		toast.head:SetText(L["Erfolg errungen"])
		toast.name:SetText(self:AchName(def))
		toast.desc:SetText(self:AchDesc(def))
	end
	toast.t = 0
	toast:SetAlpha(0)
	toast:Show()
	playSound()
end

function GS:QueueAchToast(item)
	if self.db.achToastOff then return end
	queue[#queue + 1] = item
	self:NextAchToast()
end

---------------------------------------------------------------------------
-- Prüfen: neu errungene Erfolge des eigenen Kontos
---------------------------------------------------------------------------
function GS:CheckAchievements()
	local g = self:G()
	if not g or not self.player then return end
	local main = self:AccountOf(self.player)
	if not self:Calc().accounts[main] then return end
	g.achSeen = g.achSeen or {}
	local firstRun = g.achSeen[main] == nil
	local seen = g.achSeen[main] or {}
	g.achSeen[main] = seen
	local new = {}
	local now = self:Now()
	for _, s in ipairs(self:AchievementStates(main)) do
		if s.done and not seen[s.def.id] then
			seen[s.def.id] = now
			new[#new + 1] = s.def
		end
	end
	if #new == 0 then return new end
	-- bis ACH_SINGLE_MAX einzeln (Banner nacheinander), darüber ein Sammelbanner; Links stehen immer einzeln im Chat
	local many = #new > self.ACH_SINGLE_MAX
	if many then
		self:Print(LF("Du hast %d Finanzamt-Erfolge freigeschaltet – siehe Mein Konto, Erfolge:", #new))
		self:QueueAchToast({ summary = #new })
	end
	for _, def in ipairs(new) do
		local link = self:AchLink(def.id, self.player, now)
		self:Print((many and "  " or L["Erfolg errungen: "]) .. link)
		if not many then self:QueueAchToast({ id = def.id, t = now }) end
	end
	-- Gildenchat: nie beim ersten Start (rückwirkend freigeschaltet, nicht gerade errungen)
	if not firstRun and not many and self:AchChatEnabled() then
		for _, def in ipairs(new) do self:SendAchChat(def) end
	elseif self.debug then
		self:Print(LF("Erfolge nicht im Gildenchat: %s", firstRun and L["erster Start"] or many and L["zu viele auf einmal"] or L["Gildenchat-Meldungen aus"]))
	end
	if UI and UI.Refresh then UI:Refresh() end
	return new
end

GS:Register("DATA_CHANGED", function() GS:Debounce("ach", 15, function() GS:CheckAchievements() end) end)
GS:Register("GUILD_READY", function()
	C_Timer.After(75, function() GS:CheckAchievements() end) -- nach Sync und Steuerbescheid
	if not GS._achTicker then GS._achTicker = GS:Ticker(600, function() GS:CheckAchievements() end) end
end)

-- Test: /gst erfolgtest
function GS:TestAchToast()
	local list = self.ACHIEVEMENTS
	local def = list[math.random(1, #list)]
	self:Print(LF("Test: %s", self:AchLink(def.id, self.player, self:Now())))
	queue[#queue + 1] = { id = def.id, t = self:Now() }
	self:NextAchToast()
end
