(* Industrial Simulator - programme de demonstration Phase 3
   Machine : convoyeur_01 (usine : simulator/config/factory.json)

   Logique d'automatisme exigee par le cahier des charges :
     SI sensor_entry = TRUE  ALORS conveyor.run = TRUE
     SI sensor_exit  = TRUE  ALORS conveyor.run = FALSE

   Adressage (slave device "simulateur" declare dans OpenPLC) :
     %IX100.0 <- discrete input 0 du simulateur (sensor_entry)
     %IX100.1 <- discrete input 1 du simulateur (sensor_exit)
     %QX100.0 -> coil 0 du simulateur (conveyor_01.run)

   NB important : OpenPLC range les E/S des devices distants a partir de
   %I/%Q100 (voir updateBuffersIn_MB dans core/modbus_master.cpp) ; la bande
   basse (%I0/%Q0) est reservee a l'image de son propre serveur Modbus.

   Le maintien de la marche (memoire SET/RESET) est assure par ces deux
   affectations : conveyor_run garde sa valeur tant qu'aucun capteur n'agit.
   C'est la logique d'automatisme, elle vit dans le PLC, pas dans le simulateur.

   OpenPLC v3 exige un programme IEC 61131-3 complet : PROGRAM + CONFIGURATION.
   La tache Main est executee toutes les 50 ms ; la scrutation Modbus du
   simulateur est reglee cote OpenPLC (Slave_polling, defaut 100 ms). *)

PROGRAM prog0
  VAR
    sensor_entry AT %IX100.0 : BOOL;
    sensor_exit AT %IX100.1 : BOOL;
    conveyor_run AT %QX100.0 : BOOL;
  END_VAR

  IF sensor_entry THEN
    conveyor_run := TRUE;    (* capteur d'entree : marche *)
  END_IF;

  IF sensor_exit THEN
    conveyor_run := FALSE;   (* capteur de sortie : arret *)
  END_IF;
END_PROGRAM


CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK Main(INTERVAL := T#50ms,PRIORITY := 0);
    PROGRAM Inst0 WITH Main : prog0;
  END_RESOURCE
END_CONFIGURATION
