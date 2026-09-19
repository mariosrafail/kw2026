# KW — Roadmap, κριτήρια επιτυχίας και αποφάσεις

**Κατάσταση:** προτεινόμενο πλάνο v1.0. Οι αριθμοί παρακάτω είναι εσωτερικοί στόχοι αξιολόγησης, όχι δεδομένα αγοράς ή ήδη μετρημένα αποτελέσματα. Δεν έχει δοθεί από τον χρήστη συγκεκριμένο budget, ομάδα ή ημερομηνία κυκλοφορίας.

## 1. Κανόνας προτεραιότητας

Πρώτα αποδεικνύουμε ότι δύο άνθρωποι παίζουν το ίδιο καλό παιχνίδι. Μετά ότι τέσσερις θέλουν να ξαναπαίξουν. Μετά ότι ένας νέος creator μπορεί να φτιάξει κάτι που η παρέα του θέλει να παίξει. Μόνο τότε κλιμακώνουμε δημόσιο UGC και κονσόλες.

Η προοπτική κονσολών δεν περιμένει μέχρι το τέλος: approval/port-provider investigation και controller design τρέχουν νωρίς. Η μαζική παραγωγή ports και marketing δεσμεύσεις περιμένουν τις αντίστοιχες αποδείξεις.

## 2. Παραδοτέα με gates

### G0 — Καταγεγραμμένο baseline και playable checkpoint

Snapshot του σημερινού 3D prototype, των user-edited sources και της υπάρχουσας κατάστασης Git. Ελεγμένο checkpoint commit/backup αφού εγκριθεί, χωρίς να περιληφθούν secrets, SDKs ή προσωρινά logs. Το παλιό 2D main menu και το 3D reference διατηρούνται.

Παραδοτέο: reproducible local build, καταγραφή controls/settings και μικρή suite που αποδεικνύει σημερινό movement, aiming, grenade, waves, heal και UI. Η επιτυχία φαίνεται σε πραγματικό run και log, όχι σε μήνυμα «exit 0» αν υπάρχουν script errors.

### G1 — Input και διαχωρισμός simulation/presentation

Actions αντί hardcoded gameplay keys. Actor με health/weapon/skill state ανά entity. Αφαίρεση camera/HUD από authoritative rules. Επιλογή SessionConfig και πρώτο primitive LevelDefinition.

Gate: 20 λεπτά gameplay/menus από controller χωρίς mouse· δεύτερος local actor μπορεί να υπάρχει χωρίς να αναφέρεται όλος ο κώδικας στον ίδιο `stage.player`. Headless simulation αρχίζει/τελειώνει match χωρίς graphics/audio dependencies.

### G2 — Πραγματικό 3D online proof

Ένας server και δύο clients. Input prediction, authoritative events, remote actor interpolation, grenade/explosion consistency και disconnect/rejoin. Στο τέλος τέσσερις clients σε σύντομο co-op match.

Gate: ίδιο kill/health/cooldown σε όλους, κανένα duplicate effect/damage από retry, μπλοκάρισμα αδύνατων client requests. Δοκιμές native localhost/LAN και ξεχωριστών δικτύων. Ελεγχόμενα σενάρια 0/80/120 ms RTT, jitter και packet loss. Ένα client σε controller, ένα σε mouse. Καταγεγραμμένη μέτρηση server frame time, όχι υπόθεση ότι low-poly σημαίνει δωρεάν CPU.

Στην παρούσα φάση αξιολογείται provider/transport path για κονσόλες. Δεν αναβαθμίζουμε/αντικαθιστούμε engine χωρίς compatibility matrix και regressions.

### G3 — Vertical slice που κλείνει μόνο του

Ένα ολοκληρωμένο Riot Run 1–4 παικτών, μία polished arena, δύο enemy behaviors, AK + δεύτερο διακριτό weapon archetype, grenade + ένα utility skill, περιορισμένη gadget preparation και σαφές τέλος/rematch. Δεν προσθέτουμε ακόμη όλα τα cosmetics ή 20 παραλλαγές όπλων.

Gate: μικρό κλειστό playtest με τουλάχιστον 12 άτομα σε παρέες. Αρχικοί στόχοι: τουλάχιστον 10/12 ολοκληρώνουν πρώτο match χωρίς live εξήγηση και τουλάχιστον 8/12 επιλέγουν μόνοι τους δεύτερο run. Αυτή είναι ένδειξη, όχι στατιστική απόδειξη επιτυχίας. Καταγράφουμε συγκεκριμένα πού βαρέθηκαν/μπερδεύτηκαν και ξαναδοκιμάζουμε σε νέους ανθρώπους.

### G4 — Builder που χρησιμοποιούμε και εμείς

Versioned data-only level format, prefab catalog, single-user editor με gamepad, undo/save/load/playtest και private file/code sharing. Τα τρία πρώτα δικά μας maps φτιάχνονται με αυτόν.

Gate: 8/10 νέοι testers μπορούν, μετά από σύντομο tutorial, να αλλάξουν template και να παίξουν τη δημιουργία τους μέσα σε 10 λεπτά. Save/load δεν αλλάζει geometry/rules. Malformed data και υπέρβαση budgets απορρίπτονται με συγκεκριμένο μήνυμα. Λείπει prefab/έκδοση; το match δεν αρχίζει με μισό χάρτη.

### G5 — Steam playtest και λειτουργική κοινότητα

Platform login/invites, deploy pipeline, crash reporting, account restrictions, βασικό UGC private/curated catalog, safety controls και οικονομικές μετρήσεις hosting. Διατήρηση solo/offline περιεχομένου όταν πέσει η υπηρεσία.

Gate: 30λεπτα sessions με επανειλημμένες συνδέσεις/αποσυνδέσεις, μέτρηση join success και clear failure reasons. Πρώτοι creators εκτός ομάδας φτιάχνουν διαφορετικά playable maps. Support/report έχει συγκεκριμένο owner. Χωρίς λειτουργικό moderation δεν ανοίγει unrestricted public publishing.

### G6 — PvP και συμβατότητα πραγματικών πλατφορμών

Hot Core 2–8 παικτών σε private rooms, validated controller/mouse policy, lag compensation και μικρό map pool. Παράλληλα πρώτη approved console build που παίζει στο ίδιο test server με PC, με permissions, invites και shared level revision.

Gate: η κονσόλα δεν έχει μόνο boot screen. Παίζει πλήρες match, δημιουργεί/κατεβάζει approved map, κάνει resume/reconnect και βγάζει σωστό profile logout. Cosmetic animation δεν μεταβάλλει unfair hitboxes. Public ranked mode παραμένει εκτός scope.

### G7 — Release candidate και επεκτάσεις

Steam release ή χρηστικό Early Access μόνο όταν το προϊόν έχει ολοκληρωμένο core loop και σαφή κατάσταση χαρακτηριστικών. Ξεχωριστό console certification/release gate. Public workshop, περισσότερα maps και co-editing επεκτείνονται με μετρημένη capacity.

Το store page αναφέρει μόνο πραγματικά διαθέσιμα χαρακτηριστικά ή ξεκάθαρα μελλοντικά σχέδια. Δεν εμφανίζει λογότυπα/ημερομηνίες για μη επιβεβαιωμένα ports και δεν παρουσιάζει τεχνικό spike σαν υποστηριζόμενο commercial feature.

## 3. Η πρώτη συγκεκριμένη δέσμη εργασίας

Η επόμενη υλοποίηση πρέπει να περιοριστεί σε τέσσερα πράγματα: baseline checkpoint, πλήρες InputMap/gamepad, per-actor state αντί μοναδικού `stage.player`, και headless server με δύο 3D clients. Ούτε άλλα δέκα enemies ούτε καινούργιο soundtrack στο ίδιο πακέτο.

Το σταθερό physics/combat μέρος γίνεται ξεχωριστό από την εικόνα. Το σημερινό player model και spring feel παραμένουν reference. Το πρώτο level schema μπορεί να περιγράψει μόνο τη σημερινή αρένα. Δεν χρειάζεται να τελειώσουμε τον δημόσιο editor για να αποδείξουμε online.

Στο ίδιο χρονικό σημείο προετοιμάζεται μικρό pitch/demo και τεχνικό ερωτηματολόγιο για console provider. Δεν υποβάλλεται τίποτα ή αγοράζεται middleware χωρίς την απαραίτητη ξεχωριστή εντολή.

## 4. Quality matrix και μη διαπραγματεύσιμα tests

| Περιοχή | Απόδειξη |
|---|---|
| Combat | Ίδιο hit/kill/heal στο server και στους clients. Grenade ένα damage event ανά αντίπαλο. |
| Aim | Camera/muzzle convergence, cover, κοντινός στόχος, Q shoulder swap, ADS και διαφορετικές αναλύσεις. |
| Movement | Forward/back/strafe, ramps, platforms, landing, disconnect correction, no stuck inputs. |
| Animation | Head gaze σωστό, feet ανά κατεύθυνση, bounded wobble, ορατή/πραγματική combat pose συμβατή. |
| UGC | Limits server-side, invalid refs, oversized/compressed payload, forbidden code/path, version mismatch. |
| Online | Rejoin, late join, timeout, host loss, privilege change, blocked users. |
| Controller | Boot → login → party → play → editor → save → settings → exit χωρίς mouse. |
| Performance | Worst legal map, AI/physics caps, grenade burst, outline on/off, πραγματικό minimum device. |
| Audio/accessibility | Spatial mix, speech/telegraph readability, motion/flash/damage-number settings. |
| Persistence | Corrupt/full save, interrupted write, stale cloud save, account switch, catalog update. |

Αρχικό performance target: σταθερά 60 fps σε επιλεγμένο ελάχιστο PC/Deck profile, με simulation budget που αφήνει περιθώριο. Το ακριβές minimum hardware δεν ορίζεται από το επιτυχημένο run στον τωρινό υπολογιστή. Κάθε console profile ελέγχεται στο συγκεκριμένο hardware.

## 5. Κόστος: τι πρέπει να υπολογιστεί πριν δεσμευθούμε

Οι κύριες κατηγορίες είναι ανάπτυξη/QA, dedicated servers, relay/egress, UGC storage/CDN, moderation/support, console porting/middleware, πραγματικές συσκευές δοκιμής, ratings/localization και artwork/audio licensing. Δεν έχουμε ακόμη πραγματικές προσφορές για KW, οπότε δεν παρουσιάζουμε αυθαίρετο ποσό ως budget.

Ένα χρήσιμο μοντέλο λειτουργικού κόστους:

```text
active_rooms ≈ average_concurrent_players / average_players_per_room
host_hours ≈ active_rooms × hours_in_period / benchmarked_rooms_per_host
monthly_ops ≈ host_hours × quoted_host_rate
            + relay/traffic + UGC storage/CDN + identity/services
            + monitoring + moderation/support + reserve_capacity
```

Η μέση πληρότητα δωματίου έχει σημασία. Τέσσερις θέσεις δεν σημαίνει ότι κάθε room είναι γεμάτο. Peak capacity, idle warm servers, regional fragmentation και platform-specific queues αυξάνουν κόστος. Public sandbox με έναν άνθρωπο ανά room είναι ακριβότερο ανά player από γεμάτο co-op.

Υπηρεσίες όπως EOS και mod.io αξιολογούνται ως συγκεκριμένες προσφορές/SDKs [S14–S18], όχι γενική υπόσχεση δωρεάν multiplayer και moderation. Σύγκριση με self-hosting περιλαμβάνει χρόνο λειτουργίας/υποστήριξης, όχι μόνο τιμή VPS.

Προτεινόμενη διάθεση πόρων στην αρχή: το μεγαλύτερο βάρος σε input/netcode/game feel, μετά σε πραγματικό co-op content, και μετά στον editor/UGC. Παράλληλος μικρός console feasibility έλεγχος. Δεν ανοίγουμε όλα τα expensive workstreams την ίδια στιγμή.

## 6. Επτά ουσιαστικές αποφάσεις προς έγκριση

| ID | Πρόταση | Γιατί | Κατάσταση |
|---|---|---|---|
| D01 | Το KW γίνεται μικρών αρένων sandbox party shooter, όχι τεράστιο survival world. | Στηρίζεται στο σημερινό feel και περιορίζει άσχετο scope. | Προτεινόμενη. |
| D02 | Πρώτο flagship: 1–4 co-op Riot Run. PvP 2–8 private ακολουθεί. | Γρήγορη χρήση των waves, μετά ξεχωριστό competitive tuning. | Προτεινόμενη. |
| D03 | Godot παραμένει, με early console/provider spike. | Προστασία υπάρχουσας δουλειάς χωρίς ψεύτικη console εγγύηση. | Προτεινόμενη. |
| D04 | Data-only maps με approved blocks/devices και κοινό catalog. | Portable creation, ασφάλεια και μικρά downloads. | Προτεινόμενη. |
| D05 | Dedicated authoritative online βάση, private hosting προαιρετικά. | Ίδιο combat state και σαφές trust model. | Προτεινόμενη. |
| D06 | Steam πρώτα, controller/Deck από νωρίς, PS5 ως πρώτη console προτεραιότητα. | Γρήγορο feedback και αποφυγή πολλαπλών μη ελεγμένων launches. | Προτεινόμενη. |
| D07 | Premium game, χωρίς pay-to-win ή paid gameplay blocks. | Μη διασπασμένη κοινότητα και μικρότερο live-service βάρος. | Προτεινόμενη. |

Δεν απαιτείται να απαντηθούν όλες πριν από το πρώτο τεχνικό πείραμα. Δεν πρέπει όμως να παρουσιάζονται ως λόγια/επιλογές του χρήστη σε επόμενη συνεδρία μέχρι να τις εγκρίνει.

## 7. Ρίσκα και πότε αλλάζουμε πορεία

Αν η στόχευση χαλάει online, σταματά content production και περιορίζεται η hit-affecting animation. Αν ο editor είναι δύσκολος με χειριστήριο, μειώνεται ο αριθμός εργαλείων/prefab parameters, όχι η υποστήριξη controller. Αν το κοινό μοιράζεται σε άδεια rooms, μειώνονται queues και προβάλλονται γρήγορα curated sessions.

Αν οι maps εκτός ομάδας δεν είναι ενδιαφέρουσες, παρέχονται καλύτερα templates/objectives και η δημόσια UGC βιβλιοθήκη περιμένει. Αν το κόστος moderation δεν καλύπτεται, μένουμε σε approved/private sharing. Αν ένα console SDK/provider δεν υποστηρίζει το τεχνικό stack, αλλάζουμε adapter/engine branch ή σειρά port, όχι ολόκληρη την ταυτότητα του παιχνιδιού χωρίς πείραμα.

Αν οι playtesters γελούν αλλά δεν θέλουν δεύτερο match, ενισχύουμε αποφάσεις και objectives, όχι μόνο περισσότερο screen clutter. Αν όλες οι δυνατές επιλογές κάνουν τον παίκτη να χάνει έλεγχο, αφαιρούμε τα μη προβλέψιμα stuns. Η φυσική πρέπει να δίνει ιστορίες, όχι δικαιολογίες για bugs.

## 8. Τι σημαίνει «έτοιμο πλάνο»

Έτοιμο πλάνο δεν σημαίνει ανακοινωμένη ημερομηνία. Μετά τα G1–G2 μπορεί να γίνει σοβαρή εκτίμηση effort για το vertical slice και να αναζητηθούν συγκεκριμένες προσφορές console/UGC. Χωρίς αυτά, ακριβής προθεσμία για Steam + PlayStation + όλες τις πλατφόρμες θα ήταν ατεκμηρίωτη.

Η πιο χρήσιμη επόμενη απόδειξη είναι μικρή και σαφής: **δύο άνθρωποι, σε δύο clients, παίζουν το ίδιο KW 3D με το ίδιο καλό feel**. Όλο το μεγαλύτερο όραμα χτίζεται πάνω σε αυτή την απόδειξη.
