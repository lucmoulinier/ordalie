# Ordalie

Ordalie (ORDered ALignment Information Explorer) est un atelier Tcl/Tk pour l'exploration
d'alignements multiples de séquences : édition, regroupement des séquences, phylogénie,
conservation, annotations, et projection sur les structures 3D, le tout organisé en
instances analytiques conservées dans une base SQLite (fichiers ORD).

Licence : GNU GPL version 3 (voir `LICENSE`).

## Contenu du dépôt

- `src/` : le code Tcl d'Ordalie (`ordali_*.tcl`, chargés dans l'ordre de
  `ordali_source.tcl`) et `LesProcsDeGscope.tcl`, la partie de Gscope dont Ordalie a besoin.
- `lib/` : les paquets Tcl pur utilisés par Ordalie (tcllib, tablelist, struct, ...).
- `etc/` : ressources chargées à l'exécution (icônes, curseurs, matrices de substitution,
  couleurs, DTD MACSIM, glyphes).
- `doc/` : sources LaTeX de la documentation, figures, bibliographie ; `dodoc` construit
  le PDF, `dohtml` le HTML (l'aide intégrée ouvre `doc/ordalie_documentation/index.html`).
- `test/` : tests (scripts Tcl lancés avec tclsh/wish, banc d'essai GUI dans `test/banc`).
- `packages/` : sous-modules git des paquets C d'Ordalie (biotext, tclordalie,
  tclcluspack, tclfastme, tclsurface, LRIPhoto).
- `Build/` : scripts et textes de packaging (installateurs Linux/macOS, `ordalie.iss`
  pour Windows).

Récupération avec les sous-modules :

    git clone --recurse-submodules https://github.com/lucmoulinier/ordalie.git

## Ce qui n'est pas dans le dépôt

Les binaires ne sont pas versionnés. Pour lancer Ordalie depuis les sources, il faut
en plus, dans `lib/` (ou ailleurs dans `auto_path`), les paquets compilés pour la plateforme :

- paquets d'Ordalie, à compiler depuis `packages/` : biotext, tclordalie, tclcluspack,
  tclfastme, tclsurface, LRIPhoto ;
- paquets tiers : tcl3d (OpenGL), tdom, sqlite3, tcltls, TclCurl, Img, Tkhtml ;
- tclstride et tclswalign (sources non incluses) ;
- MAFFT 7.471 dans `bin/mafft-<plateforme>` (facultatif).

Interpréteur conseillé : Tcl/Tk 8.6 avec le paquet sqlite3 (de préférence une version
récente avec `serialize`/`deserialize` ; à défaut, Ordalie se replie sur backup/restore).

## Lancement

    ORDALIDIR=/chemin/vers/ordalie wish8.6 src/ordali.tcl [fichier]

Formats lus : MACSIM (`.xml`, `.macsim`), FASTA, MSF, CLUSTAL, ORD.

## LesProcsDeGscope.tcl

Ce fichier ne contient que les procs de Gscope utilisées par Ordalie, directement ou
indirectement (3 066 sur les 9 309 du dump complet produit par `ToutesLesProcsDeGscope`,
`src/ordali_admin.tcl`), sans les mots de passe de bases de données qu'il contenait.
Les outils de réduction et de vérification sont dans `test/reduction_gscope`.

## Tests

Les tests sont des scripts autonomes (`test/*_test.tcl`, `test/saisies/lance.sh`,
`test/phase3/lance.sh`) qui pilotent Ordalie dans un Xvfb via le banc `test/banc`.
Ils contiennent encore des chemins propres à la machine de développement
(`/home/moumou/...`) qu'il faut adapter.
