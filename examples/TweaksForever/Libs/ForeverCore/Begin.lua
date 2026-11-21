local addon, host = ...
host.ForeverCoreCopy = ForeverCoreLoader.Begin(addon, 1015004, "776765bb3312f6b30dbf091cc11a00be63fb7f744be92f7bf877a8cab570988b", 37)
local offered, reason = ForeverCoreLoader.OfferStore(addon, "TweaksForeverDB")
assert(offered or reason == "late", reason)
