local addon, host = ...
host.ForeverCoreCopy = ForeverCoreLoader.Begin(addon, 1015006, "c691e7d04073ee77830eeff191c86bd097af72e9000c9bee7fe165a2d951091a", 37)
local offered, reason = ForeverCoreLoader.OfferStore(addon, "FieldGuideForeverDB")
assert(offered or reason == "late", reason)
