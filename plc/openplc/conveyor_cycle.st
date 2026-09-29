(* Industrial Simulator - Phase 4 : cycle continu
   Variante du programme convoyeur : la boite ne reste pas bloquee au
   capteur de sortie ; apres 2 s de pause, le convoyeur l'evacue, puis
   se remet en attente de la boite suivante.

   Sequence (GRAFCET equivalent) :
     ATTENTE --entree--> MARCHE --capteur sortie--> ARRET(2s)
     ARRET --2s--> EVACUATION --boite liberee + 1s--> ATTENTE

   Adressage identique a conveyor.st (bande %I/%Q100 des devices distants). *)

PROGRAM prog0
  VAR
    sensor_entry AT %IX100.0 : BOOL;
    sensor_exit AT %IX100.1 : BOOL;
    conveyor_run AT %QX100.0 : BOOL;
  END_VAR
  VAR
    (* NB : ce matiec refuse de melanger variables AT et variables internes
       dans un meme bloc VAR - d'ou les deux blocs. *)
    pause_ton : TON;      (* delai d'arret sur le capteur de sortie *)
    tail_ton : TON;       (* delai d'evacuation apres liberation du capteur *)
    evacuating : BOOL;
  END_VAR

  (* Marche / arret nominaux *)
  IF sensor_entry AND NOT evacuating THEN
    conveyor_run := TRUE;
  END_IF;

  IF sensor_exit THEN
    conveyor_run := FALSE;
  END_IF;

  (* Apres 2 s posee sur le capteur de sortie : evacuer *)
  pause_ton(IN := sensor_exit, PT := T#2s);
  IF pause_ton.Q THEN
    evacuating := TRUE;
  END_IF;

  IF evacuating THEN
    conveyor_run := TRUE;
    (* la boite a quitte le capteur : encore 1 s pour la faire tomber au bout *)
    tail_ton(IN := NOT sensor_exit, PT := T#1s);
    IF tail_ton.Q THEN
      conveyor_run := FALSE;
      evacuating := FALSE;
    END_IF;
  END_IF;
END_PROGRAM


CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK Main(INTERVAL := T#50ms,PRIORITY := 0);
    PROGRAM Inst0 WITH Main : prog0;
  END_RESOURCE
END_CONFIGURATION
