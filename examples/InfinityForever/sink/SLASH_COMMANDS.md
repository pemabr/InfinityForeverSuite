# Infinity Suite - Complete Slash Command Reference

## Core Commands

### Loot Management
| Command | Usage | Description |
|---------|-------|-------------|
| `/loot` | `/loot` | Main loot manager interface |
| `/decay` | `/decay [config]` | Configure point decay settings |
| `/awards` | `/awards <player> <ep/gp> <reason>` | Award or spend points |
| `/loothistory` | `/loothistory [player]` | View loot award history |

### Auctions & Bidding
| Command | Usage | Description |
|---------|-------|-------------|
| `/dkpui` | `/dkpui` | Toggle DKP auction UI |

### DKP Trading
| Command | Usage | Description |
|---------|-------|-------------|
| `/dkptrade` | `/dkptrade [player] [amount]` | Request DKP trade or view history |
| `/trade` | `/trade [player] [amount]` | Shortcut for DKP trading |

### Taxation System
| Command | Usage | Description |
|---------|-------|-------------|
| `/dkptax` | `/dkptax [config]` | Tax configuration menu |
| `/tax` | `/tax [config]` | Shortcut for taxation commands |

**Taxation Sub-commands:**
- `/dkptax rate <value>` - Set tax rate (DKP per 100 gold)
- `/dkptax donation <value>` - Set donation rate
- `/dkptax whitelist <itemid>` - Add item to tax whitelist
- `/dkptax blacklist <itemid>` - Add item to tax blacklist
- `/dkptax history <player>` - View player's tax history

### Point Auditing
| Command | Usage | Description |
|---------|-------|-------------|
| `/pointaudit` | `/pointaudit <player> [days]` | View player audit report |
| `/audit` | `/audit <player> [days]` | Shortcut for point auditing |

**Auditing Sub-commands:**
- `/pointaudit sources <player>` - Show EP sources for player
- `/pointaudit items <player>` - Show GP items for player
- `/pointaudit anomalies <player>` - Detect suspicious activity

---

## Testing & Validation

### Comprehensive Testing
| Command | Usage | Description |
|---------|-------|-------------|
| `/lottests` | `/lottests` | Run comprehensive test suite (100+ assertions) |

**What's tested:**
- EPGP system functionality
- Loot history tracking
- Decay system calculation
- Auction system bidding
- Access control permissions
- DKP trading workflow
- Point auditing queries

### Integration Testing
| Command | Usage | Description |
|---------|-------|-------------|
| `/integrationtest` | `/integrationtest` | Run cross-addon integration tests |
| `/inttest` | `/inttest` | Shortcut for integration testing |

**What's tested:**
- Core addon loading
- Optional addon graceful degradation
- Loot-Healing integration
- Navigation-Inventory integration
- Event messaging between addons
- Keybind collision detection
- Performance baseline (<5ms queries)
- Character tracking
- Slash command availability
- Error handling and recovery

---

## Performance & Optimization

### Performance Profiling
| Command | Usage | Description |
|---------|-------|-------------|
| `/perfreport` | `/perfreport` | Display CPU usage report |

**Shows:**
- Slowest functions ranked by average execution time
- Call counts and total time spent
- Maximum execution time per function
- Performance bottlenecks

### Compatibility Checking
| Command | Usage | Description |
|---------|-------|-------------|
| `/compcheck` | `/compcheck` | Check addon compatibility |
| `/indepcheck` | `/indepcheck` | Check addon independence |

**Checks:**
- Keybind conflicts between addons
- Global variable collisions
- Event registration conflicts
- Optional addon dependencies

---

## Data Integrity & Recovery

### Data Verification
| Command | Usage | Description |
|---------|-------|-------------|
| `/verify` | `/verify` | Verify data integrity |

**Checks:**
- EPGP data consistency
- Loot history integrity
- DKP transaction validity
- Orphaned references
- GP calculations accuracy

### Data Repair
| Command | Usage | Description |
|---------|-------|-------------|
| `/repair` | `/repair` | Auto-repair detected data issues |

**Repairs:**
- Remove orphaned references
- Recalculate player priorities
- Fix inconsistent data

---

## Diagnostics & Debugging

### Full Diagnostics Report
| Command | Usage | Description |
|---------|-------|-------------|
| `/diag` | `/diag` | Display full diagnostic report |
| `/diagnostics` | `/diagnostics` | Long form for diagnostics |

**Displays:**
- Addon load status
- Memory usage estimates
- Active event listeners
- Data integrity status
- Performance metrics

### View Logs
| Command | Usage | Description |
|---------|-------|-------------|
| `/logs` | `/logs [count]` | View recent log entries |

**Examples:**
- `/logs` - Show last 20 log entries
- `/logs 50` - Show last 50 entries

### Debug Mode
| Command | Usage | Description |
|---------|-------|-------------|
| `/infinitydebug` | `/infinitydebug on|off` | Enable/disable debug output |

**When enabled:**
- All commands print detailed debug information
- Performance metrics displayed in real-time
- Event logs printed to chat

---

## Command Categories

### For Guild Masters
- `/loot` - Manage loot auctions
- `/decay` - Configure decay system
- `/dkptax` - Set taxation rates
- `/compcheck` - Verify addon compatibility
- `/diag` - System diagnostics
- `/verify` - Data integrity check

### For Raiders
- `/dkptrade [player] [amount]` - Request DKP trades
- `/pointaudit <player>` - View player audit history
- `/loothistory [player]` - Check loot awards
- `/dkpui` - View auctions and bid

### For Developers/Admins
- `/lottests` - Comprehensive test suite
- `/integrationtest` - Cross-addon tests
- `/perfreport` - Performance profiling
- `/indepcheck` - Addon independence
- `/logs [count]` - View system logs
- `/infinitydebug on` - Enable debug mode
- `/repair` - Data repair tool

---

## Examples

### Award Points to Player
```
/awards Thrall 100 "Killed Onyxia"
```

### Request DKP Trade
```
/dkptrade "Jaina" 50
```

### Configure Taxation
```
/dkptax rate 0.01
/dkptax donation 0.015
/dkptax whitelist 12345
```

### Audit Player Activity
```
/pointaudit "Thrall" 30
/pointaudit sources "Thrall"
/pointaudit anomalies "Thrall"
```

### Run All Tests
```
/lottests
/integrationtest
/perfreport
/verify
```

---

## Status Indicators

| Icon | Meaning |
|------|---------|
| ✓ | Success / Passed |
| ✗ | Failed / Error |
| ◆ | Warning / Optional |
| ⚠ | Critical Issue |

---

**Last Updated**: Session 3f425d47 (Checkpoint 011)
**Total Commands**: 25+ across all categories
**Fully Documented**: Yes
**All Tested**: Yes via /integrationtest
