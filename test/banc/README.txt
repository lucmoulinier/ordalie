Banc d'essai GUI d'Ordalie (phase 0 de l'audit, 2026-11-02)
  gui_instance.sh start N [fichier]  : Xvfb :(80+N) avec GLX, HOME isolé, copie du fichier, wish + sonde, port 4500+N
  gui_instance.sh stop N | status N | shot N fichier.png
  probe.sh N 'script'                : évalue dans l'instance (inspection rapide)
  probe.sh N -fire [-wait ms] 'script' : action lancée hors du handler ; bilan : code, temps, mode avant/après,
                                       nouvelles fenêtres, dialogues remplacés, erreurs de fond ; BLOCKED + pile si
                                       l'action attend (tkwait d'une fenêtre de dialogue Ordalie)
  probe::answer <dialogue> <réponse> : réponse scriptée (tk_dialog, tk_messageBox, tk_getOpenFile, tk_getSaveFile,
                                       Entre, ChoixParmi, OuiOuNon) ; défaut = annuler
  probe::widgets ?racine? / probe::dump_tree fichier.json ?racine?
Journaux dans $GUI_BASE/instN : errors.log (erreurs de fond), caught.log (erreurs attrapées, dédupliquées),
dialogs.log (dialogues remplacés), stdout.log.
Remplacés : FaireLire, tk_dialog, tk_messageBox, tk_get*File, tk_chooseColor/Directory, Entre, ChoixParmi, OuiOuNon,
exit, PrintSetup, LanceDoc, LogInBrowser.
Couverture : GUI_PROBE_COV=fichier (cumulatif) avant gui_instance.sh start ; rapport : tclsh couverture.tcl REP SORTIE.md ODIR

Phase 2 (2026-11-04) : GUI_SAISIES=1 active les saisies de l'explorateur (saisies.tcl) :
  champs remplis (valeurs valides, puis invalides une à une avant validation), dialogues répondus (probe::auto),
  choix vides faits (probe::remplit), retour à une instance neuve si le fichier a changé (probe::empreinte),
  résultat VALID = action bloquée par un message de validation. GUI_RESEAU = accès réseau par genre et par exécution (défaut 2).
  gen_donnees.tcl fabrique donnees/T_riche.ord (la superposition n'est pas sauvée dans l'ORD : SupRotTrans vide à la réouverture).

Phase 3 (2026-11-06) : GUI_INVARIANTS=1 source clordali/test/phase3/sonde.tcl dans l'instance et contrôle l'état
  après chaque action (::P3::Invariants : I1-I2 ListePDB = structures de l'instance, I3 noms colorés, I4 séquences
  cohérentes, I5 Please Wait, I6 structures après Close, I7 objets 3D sans table, I8 transaction sqlite ouverte).
  Une action sans erreur qui laisse un état incohérent est classée INVARIANT. Tests : clordali/test/phase3/lance.sh.

Saisies vérifiées (2026-11-09) : clordali/test/saisies/. Un test par fenêtre ou mode à saisie, qui vérifie ce que
  produisent les champs (souvent contre un calcul indépendant), lancés par saisies/lance.sh. saisies/catalogue_test.tcl
  lance inventory.tcl et échoue si un item de menu à saisie (Entry, Text, Combobox, Spinbox, cases, listes...) n'a pas
  de test dans saisies/catalogue.txt : un nouvel item doit y être ajouté avec son test. saisies/champs.tcl (à sourcer
  dans l'instance) : ::Champs::Liste (champs d'une fenêtre et leur variable), ::Champs::Pixel (coordonnées d'une case
  ligne.colonne d'un widget Biotext, pour générer de vrais événements souris).
