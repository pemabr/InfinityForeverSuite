local addon, host = ...
host.ForeverCoreCopy = ForeverCoreLoader.Begin(addon, 1015008, "91b1a8798bb385c21172a89a5c722f3e6791234f8c514ecf92b211d6b86d9a43", 38)
local offered, reason = ForeverCoreLoader.OfferStore(addon, "ForeverCoreDB")
assert(offered or reason == "late", reason)
