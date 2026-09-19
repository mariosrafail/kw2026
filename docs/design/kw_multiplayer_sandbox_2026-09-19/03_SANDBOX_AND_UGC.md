# KW — Sandbox, level editor και περιεχόμενο χρηστών

**Κατάσταση:** προτεινόμενη προδιαγραφή v1.0. Τα formats και budgets είναι σχέδιο, όχι υλοποιημένα APIs. Δημόσιες πηγές Sxx: `00_CONTEXT_AND_SOURCES.md`.

## 1. Τι ακριβώς δημιουργεί ο παίκτης

Ο χρήστης φτιάχνει **μια μικρή αρένα με playable κανόνες**, όχι ένα ξεχωριστό εκτελέσιμο παιχνίδι. Επιλέγει layout, objects, spawns, objectives και ένα επιτρεπόμενο ruleset. Μπορεί να φτιάξει co-op άμυνα, μικρό PvP objective ή playground με mutators.

Η δημιουργία βασίζεται σε κοινό επίσημο catalog. Ένα block, μια πόρτα ή ένας jump pad είναι το ίδιο prefab σε PC, κονσόλα και dedicated server. Τα διαφορετικά graphics presets δεν αλλάζουν collision ή gameplay.

Η αρένα δεν χρειάζεται να έχει πλήρως ελεύθερο terrain. Grid snapping, blocks με προκαθορισμένες διαστάσεις, ramps, floor modules, walls και λίγα gadgets μπορούν να δώσουν μεγαλύτερο εύρος από όσο φαίνεται, με πολύ μικρότερη πολυπλοκότητα.

## 2. Τρεις βαθμίδες εργαλείων

### A. Rule presets — γρήγορα και μικρά

Ο host αλλάζει επίσημο preset: αριθμό γύρων, friendly fire, enemy wave mix, gravity, push strength, weapon pool και διαθέσιμα skills. Κάθε slider έχει server-enforced bounds και σαφή ένδειξη «Custom rules». Preset αποθηκεύεται χωριστά από τη γεωμετρία του χάρτη.

### B. Builder v1 — πραγματικός editor

Εκκίνηση από έτοιμο template. Place/select/move/rotate/duplicate/delete, grid, multi-select αργότερα, undo/redo, save slots, playtest και επιστροφή στην ίδια κατάσταση editing. Μικρό object palette με εικόνες και categories, όχι άπειρη λίστα technical names.

Πρώτο περιεχόμενο: blocks, ramps, covers, spawn groups, objectives, jump pads, doors/buttons, pickups και ένα bounded enemy spawner. Δεν χρειάζεται κώδικας χρήστη για καμία από αυτές τις λειτουργίες.

### C. Public UGC — ξεχωριστό προϊόν υπηρεσιών

Browse, search/filter, map code, thumbnail, author, tags, report, favorites, version history, remix attribution και publishing queue. Δεν θεωρούμε ότι «έβαλα Save JSON» σημαίνει ότι έχουμε πλατφόρμα κοινότητας.

Η σειρά είναι local editor → private share → moderated public catalog. Multiplayer co-editing μπορεί να ακολουθήσει όταν single-user undo και server commits είναι σταθερά.

## 3. Η ακριβής διαδρομή δημιουργίας

Ο νέος creator επιλέγει «4-player defense template». Το template έχει valid spawns και objective. Τοποθετεί μία ράμπα, κάλυψη και jump pad, διαλέγει enemy preset, πατά Playtest. Αργότερα επιστρέφει στο ίδιο σημείο editing, πατά Save και δίνει τίτλο/thumbnail.

Πριν από Publish βλέπει συγκεκριμένα αποτελέσματα: «λείπουν δύο spawn slots», «η έξοδος είναι κλειστή», «υπέρβαση physics budget», «ο trigger ενεργοποιείται υπερβολικά συχνά». Το σύστημα δεν απαντά γενικά «invalid map».

Οι άλλοι μπαίνουν με in-game code ή invite. Δεν ανοίγουν File Explorer, δεν μεταφέρουν φακέλους και δεν εγκαθιστούν scripts. Στο console flow δημιουργία, δοκιμή, ονομασία και αποθήκευση γίνονται από χειριστήριο και system text-entry όπου απαιτείται.

## 4. Data-only level format

Η πρώτη κατεύθυνση είναι `KWLevel` με αριθμητικό `schema_version`. Κάθε τοποθετημένο object έχει stable ID, catalog prefab ID, μετασχηματισμό και επιτρεπόμενες παραμέτρους. Gameplay rules έχουν versioned IDs. Οι χρηστικές περιγραφές είναι δεδομένα, όχι GDScript, C#, shaders ή URLs.

**Εννοιολογικό παράδειγμα — δεν εισάγεται ακόμη στο παιχνίδι:**

```json
{
  "schema_version": 1,
  "level_id": "kwl_example_scrapyard",
  "revision": 1,
  "catalog_version": "core-001",
  "ruleset": "coop_defense_v1",
  "profile": "portable_core_v1",
  "objects": [
    {"id": "floor_01", "prefab": "floor_16m", "position": [0, 0, 0], "yaw": 0},
    {"id": "pad_01", "prefab": "jump_pad", "position": [2, 0, -3], "yaw": 90, "parameters": {"power_preset": "medium"}}
  ],
  "spawns": [{"id": "team_start", "team": 0, "position": [0, 1, 4]}],
  "links": []
}
```

Το παράδειγμα δείχνει μόνο τη δομή. Είναι ελλιπές playable level: δεν έχει objective, πλήρη spawns, bounds ή metadata publication. Δεν πρέπει να χρησιμοποιηθεί σαν σημερινό import test ή τελική συμφωνία schema.

Τα πραγματικά collision meshes, textures, sounds και scripts των prefab IDs περιλαμβάνονται στο υπογεγραμμένο game build. Η shared level data δεν μεταφέρει απεριόριστα textures ή binary assets. Νέα επίσημα catalog packs διανέμονται ως κανονική ενημέρωση.

## 5. Γιατί όχι `.tscn`, `.pck` και user scripts

Δεν χρησιμοποιούμε scene/resource loaders γενικού σκοπού για untrusted shared content. Επιτρέπονται μόνο τα data types που ο parser κατανοεί και ο validator έχει ελέγξει. Path traversal, arbitrary resource references, object deserialization και executable code μένουν έξω από τη δημόσια/console compatible διαδρομή.

Η επιλογή data-only είναι δική μας συντηρητική αρχιτεκτονική. Ο mod.io περιγράφει συνήθεις console περιορισμούς για UGC code, με εξαιρέσεις μόνο όταν υπάρχουν κατάλληλες mitigations [S17]. Δεν ισχυριζόμαστε ότι κάθε μορφή scripting απαγορεύεται παντού ή ότι το JSON από μόνο του εξασφαλίζει έγκριση.

Private/public level names, thumbnails και κατασκευές από «ασφαλή» blocks μπορούν πάλι να είναι υβριστικά ή ακατάλληλα. Ασφαλής runtime δεν σημαίνει ασφαλές περιεχόμενο.

## 6. Ελεγχόμενη λογική χωρίς γενική γλώσσα προγραμματισμού

Αρχικά link editor τύπου event → action: `button_pressed` → `open_door`, `wave_cleared` → `activate_exit`, `timer_elapsed` → `move_platform`. Επιτρεπόμενα inputs/outputs ανά prefab και μικρό σύνολο numeric/preset values.

Δεν υπάρχουν filesystem, HTTP, eval, arbitrary function calls ή import εξωτερικών αρχείων. Οι επαναλαμβανόμενοι timers έχουν ελάχιστο διάστημα. Links που σχηματίζουν cycle απορρίπτονται ή περνούν μόνο από ρητά bounded timer nodes. Ο server μετρά execution budget και απενεργοποιεί map logic που υπερβαίνει το όριο αντί να κολλάει το room.

Ακόμη και data-only graph μπορεί να καταρρεύσει performance ή να δημιουργήσει χιλιάδες enemies. Χρειάζονται quotas στο runtime, όχι μόνο στο editor UI.

## 7. Ένα κοινό portable profile

Προτεινόμενα όρια για το πρώτο prototype του validator: έως 512 placed objects, 32 active dynamic props, 16 live AI, 64 logic devices, 128 links, level δεδομένα έως 512 KiB πριν από upload. Δεν είναι μετρημένες χωρητικότητες και δεν είναι υποσχέσεις για συγκεκριμένη κονσόλα. Θα προσαρμοστούν μετά από CPU/GPU/network tests.

Προσθέτουμε weighted budget: ένα απλό στατικό block είναι φθηνότερο από έναν moving platform ή enemy spawner. Περιορίζουμε συνολική έκταση, draw calls, light/shadow count, ενεργά projectiles και trigger operations. Το χαμηλό polygon count δεν σημαίνει αυτόματα χαμηλό κόστος όταν κάθε block/outline είναι ξεχωριστό draw call.

Αρχικά ένα κοινό profile για όλες τις προγραμματισμένες πλατφόρμες. Δεν δημιουργούμε από την πρώτη μέρα PC-only giant maps και μετά απογοητεύουμε τους console φίλους που δεν μπορούν να συμμετάσχουν. Υψηλότερα profiles αργότερα, με ξεκάθαρο compatibility badge.

## 8. Validation και publishing pipeline

`Draft → local validation → private playtest → upload → server validation → moderation → published revision`.

Schema validation, finite/bounded numbers, unique IDs, catalog allowlist, bounds, object/logic budgets, supported ruleset, spawn/objective completeness και dependency compatibility εκτελούνται και στον server. Τα συμπιεσμένα πακέτα ελέγχονται και ως προς expanded size. Ο validator δεν εμπιστεύεται client-reported «passed».

Το δημοσιευμένο level έχει immutable revision, content hash και υπηρεσιακή υπογραφή/έγκριση. Το hash ελέγχει ακεραιότητα· δεν αποδεικνύει ότι ο δημιουργός είναι ασφαλής. Το παλιό revision δεν αλλάζει ενώ τρέχει match. Update παράγει νέο revision που πρέπει να περάσει ξανά ελέγχους.

Match config δεσμεύει `(level_id, revision, content_hash, catalog_version, ruleset_version)`. Download έχει όριο χρόνου/χώρου, cancel και graceful failure. Σημαντικό: το approved flag δεν υποκαθιστά την τελική validation κατά το load.

## 9. Συνδημιουργία χωρίς griefing

Πρώτη multiplayer μορφή: ιδιωτικό room με owner, editor και playtester roles. Αποκλειστικός προσωρινός έλεγχος του object που μετακινείται και authoritative command log. Commands όπως `place`, `move`, `remove`, `set_parameter` ελέγχονται ως προς δικαιώματα και budgets.

Undo αναιρεί συγκεκριμένη ενέργεια του χρήστη αν οι προϋποθέσεις της ισχύουν ακόμη. Δεν κάνει γενικό rewind στις αλλαγές των άλλων. Autosave γράφει νέα draft checkpoints. Ο owner μπορεί να αφαιρέσει edit permission χωρίς να χάσει ο άλλος πρόσβαση ως playtester.

Playtest χρησιμοποιεί snapshot του draft. Gameplay καταστροφή/props δεν γράφονται αυτόματα πίσω στο source map. Επιστροφή στο builder επαναφέρει καθαρό draft. Οι κανόνες αυτοί λύνουν περισσότερα προβλήματα από μία εντυπωσιακή πρώτη multiplayer gizmo επίδειξη.

## 10. Ανακάλυψη περιεχομένου και αξία για creators

In-game browser με «παίχτηκε με φίλους», «νέα ελεγμένα», «σύντομα», «co-op», «PvP», «controller-ready». Δείχνει creator, διάρκεια, παίκτες, έκδοση, απαιτούμενο catalog και βασικά accessibility flags. Δεν εμφανίζει μόνο τα πιο δημοφιλή maps, γιατί οι νέοι δημιουργοί δεν θα βρίσκουν δοκιμαστές.

Save/favorite, private sharing, map code και remix attribution είναι βασικά. Ένα remix δείχνει την αλυσίδα προέλευσης και τις επιτρεπόμενες άδειες. Δεν αντιγράφει σιωπηλά το όνομα/credits του αρχικού creator. Πρόοδος/cosmetics δεν ανταμείβονται απεριόριστα σε custom maps που ο δημιουργός έκανε AFK farms.

Πριν ανοίξει η δημόσια υπηρεσία θέλουμε τουλάχιστον τρία καλά δικά μας maps και μια μικρή ομάδα creators που δοκίμασε τον editor. Ένα άδειο workshop δεν είναι feature ολοκληρωμένου προϊόντος.

## 11. Steam Workshop και κοινή βιβλιοθήκη

Προτεινόμενη ιδιοκτησία: `KWLevelId` ανεξάρτητο από storefront. Steam Workshop integration μπορεί να υπάρχει ως κανάλι distribution/discovery, όχι ως μοναδικό identity ή ως υπόθεση ότι οι κονσόλες θα ανοίγουν το ίδιο Workshop flow [S06].

Για cross-platform catalog αξιολογούμε managed UGC πάροχο, όπως mod.io, έναντι δικού μας metadata/storage/moderation backend. Ο mod.io δηλώνει υποστήριξη κονσολών με premium tier και approval [S16, S18]. Αποφασίζουμε μόνο μετά από Godot/native console integration spike και συγκεκριμένη εμπορική προσφορά. Δεν έχουμε αγοράσει ή εγκαταστήσει υπηρεσία.

Το κοινό catalog μπορεί να διανέμει διαφορετικά approved revisions/availability ανά platform όταν απαιτείται. Cross-play room επιλέγει μόνο maps επιτρεπόμενα για **όλους** τους συμμετέχοντες.

## 12. Moderation και λειτουργία

Δημόσιο UGC απαιτεί in-game report για map/creator, block/hide, content guidelines, review queue, takedown/appeal, audit log και δυνατότητα άμεσου disable μιας έκδοσης. Οι δημόσιες απαιτήσεις Xbox αναφέρουν ρητά UGC reporting/guidelines και περιορισμούς πρόσβασης [S11]. Οι άλλες πλατφόρμες ελέγχονται στη δική τους αδειοδοτημένη διαδικασία.

Καμία εγγύηση ότι το AI moderation θα αρκεί. Απαιτείται υπεύθυνος άνθρωπος για escalations. Server validation διακόπτει malicious logic, αλλά δεν κρίνει όλες τις σημασίες μιας κατασκευής. Ratings/parental controls πρέπει να εφαρμόζονται πριν από το download/preview, όχι όταν έχει ήδη εμφανιστεί το περιεχόμενο.

Το offline παιχνίδι με δικά μας levels λειτουργεί χωρίς δημόσιο UGC. Αν η υπηρεσία πέσει ή ένας λογαριασμός δεν έχει UGC privilege, δεν γίνεται όλο το παιχνίδι άχρηστο. Cached approved content ακολουθεί την πολιτική άδειας/revocation και parental restrictions της πλατφόρμας· δεν παρακάμπτει μόνιμα ένα takedown.
