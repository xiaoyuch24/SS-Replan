(define (domain nvidia-tamp)
  (:requirements :strips :equality)
  (:constants @world @gripper @stove)
  (:predicates
    (Stackable ?o ?r)
    (Stove ?r)
    (Type ?t ?b)
    (NoisyBase)
    (Movable ?o)

    (Angle ?j ?a)
    (Grasp ?o ?g)
    (Pick ?o ?p ?g ?bq ?aq ?bt)
    (Pull ?j ?q1 ?q2 ?bq ?aq ?at)
    (BaseMotion ?bq1 ?bq2 ?bt)
    (ArmMotion ?aq1 ?aq2 ?at)
    (CalibrateMotion ?bq ?aq ?at)
    (BTraj ?bt)
    (ATraj ?at)
    (Conf ?j ?q)

    (CFreeRelPoseRelPose ?o1 ?rp1 ?o2 ?rp2 ?s)
    (CFreeApproachPose ?o1 ?p1 ?g ?o2 ?p2)
    (CFreeTrajPose ?t ?o2 ?p2)

    (AtAngle ?j ?q)
    (AtGrasp ?o ?g)
    (HandEmpty)
    (AtBConf ?bq)
    (AtAConf ?aq)
    (CanMove)
    (Cooked ?o)
    (Calibrated)

    (Status ?s)
    (DoorStatus ?j ?s)
    (AngleWithin ?j ?a ?s)

    (On ?o1 ?o2)
    (Holding ?o)
    (UnsafeRelPose ?o ?rp ?s)
    (UnsafeApproach ?o ?p ?g)
    (UnsafeATraj ?at)
    (UnsafeBTraj ?bt)

    (RelPose ?o1 ?rp ?o2)
    (AtRelPose ?o1 ?rp ?o2)
    (WorldPose ?o ?p)
    (AtWorldPose ?o ?p)
    (PoseKin ?o1 ?p1 ?rp ?o2 ?p2)
    (AngleKin ?o ?p ?j ?a)
    (Connected ?o ?j)
  )
  (:functions
    (Distance ?bq1 ?bq2)
    (MoveCost ?bt)
    (PickCost)
    (PlaceCost)
    (PullCost)
    (CookCost)
  )

  (:action move_base
    :parameters (?bq1 ?bq2 ?bt)
    :precondition (and (BaseMotion ?bq1 ?bq2 ?bt)
                       (AtBConf ?bq1) (CanMove) (Calibrated)
                   )
    :effect (and (AtBConf ?bq2)
                 (not (AtBConf ?bq1)) (not (CanMove))
                 (when (NoisyBase) (not (Calibrated)))
                 (increase (total-cost) (Distance ?bq1 ?bq2)))
                 ; (increase (total-cost) (MoveCost ?bt)))
  )
  ;(:action move_arm
  ;  :parameters (?q1 ?q2 ?t)
  ;  :precondition (and (ArmMotion ?a ?q1 ?t ?q2)
  ;                     (AtAConf ?a ?q1))
  ;  :effect (and (AtAConf ?a ?q2)
  ;               (not (AtAConf ?a ?q1)))
  ;)

  ;(:action open_gripper
  ;  :parameters ()
  ;  :precondition (and (BaseMotion ?bq1 ?bq2 ?bt)
  ;                     (AtBConf ?bq1) (CanMove) (Calibrated))
  ;  :effect (and (AtBConf ?bq2)
  ;               (not (AtBConf ?bq1)) (not (CanMove))
  ;               (when (NoisyBase) (not (Calibrated)))
  ;               (increase (total-cost) (Distance ?bq1 ?bq2)))
  ;)

  (:action calibrate
    :parameters (?bq ?aq ?at)
    :precondition (and (CalibrateMotion ?bq ?aq ?at)
                       (AtBConf ?bq) ; (AtAConf ?aq)
                       (not (Calibrated))
                       ; TODO: visibility constraints
                   )
    :effect (and (Calibrated) ; Could make this be a new pose ?bq2
                 ; (not (AtBConf ?bq))
                 (increase (total-cost) (CalibrateCost)))
  )
  (:action pick
    :parameters (?o1 ?p1 ?g ?rp ?o2 ?p2 ?bq ?aq ?at)
    :precondition (and (Pick ?o1 ?p1 ?g ?bq ?aq ?at) (PoseKin ?o1 ?p1 ?rp ?o2 ?p2)
                       (AtRelPose ?o1 ?rp ?o2) (AtWorldPose ?o1 ?p1) (HandEmpty)
                       (AtBConf ?bq) (Calibrated) ; (AtAConf ?aq)
                       (not (UnsafeApproach ?o1 ?p1 ?g))
                       (not (UnsafeATraj ?at))
                  )
    :effect (and (AtGrasp ?o1 ?g) (CanMove)
                 (not (AtRelPose ?o1 ?rp ?o2)) (not (AtWorldPose ?o1 ?p1)) (not (HandEmpty))
                 (increase (total-cost) (PickCost)))
  )
  (:action place
    :parameters (?o1 ?p1 ?g ?rp ?o2 ?p2 ?bq ?aq ?at)
    :precondition (and (Pick ?o1 ?p1 ?g ?bq ?aq ?at) (PoseKin ?o1 ?p1 ?rp ?o2 ?p2)
                       (AtGrasp ?o1 ?g) (AtWorldPose ?o2 ?p2)
                       (AtBConf ?bq) (Calibrated) ; (AtAConf ?aq)
                       (not (UnsafeRelPose ?o1 ?rp ?o2))
                       (not (UnsafeApproach ?o1 ?p1 ?g))
                       (not (UnsafeATraj ?at))
                  )
    :effect (and (AtRelPose ?o1 ?rp ?o2) (AtWorldPose ?o1 ?p1) (HandEmpty) (CanMove)
                 (not (AtGrasp ?o1 ?g))
                 (increase (total-cost) (PlaceCost)))
  )
  (:action pull
    :parameters (?j ?a1 ?a2 ?o ?p1 ?p2 ?bq ?aq ?at)
    :precondition (and (Pull ?j ?a1 ?a2 ?bq ?aq ?at)
                       (AngleKin ?o ?p1 ?j ?a1) (AngleKin ?o ?p2 ?j ?a2)
                       (AtAngle ?j ?a1) (HandEmpty)
                       (AtWorldPose ?o ?p1)
                       (AtBConf ?bq) (Calibrated); (AtAConf ?aq)
                       ; TODO: ensure the final conf is safe
                       (not (UnsafeATraj ?at))
                  )
    :effect (and (AtAngle ?j ?a2) (CanMove)
                 (not (AtAngle ?j ?a1))
                 (AtWorldPose ?o ?p2)
                 (not (AtWorldPose ?o ?p1))
                 (forall (?o3 ?p3 ?rp3) (when (and (PoseKin ?o3 ?p3 ?rp3 ?o ?p1)
                                                   (AtRelPose ?o3 ?rp3 ?o))
                                              (not (AtWorldPose ?o3 ?p3))))
                 (forall (?o4 ?p4 ?rp4) (when (and (PoseKin ?o4 ?p4 ?rp4 ?o ?p2)
                                                   (AtRelPose ?o4 ?rp4 ?o))
                                              (AtWorldPose ?o4 ?p4)))
                 (increase (total-cost) (PullCost)))
  )

  (:action cook
    :parameters (?r)
    :precondition (Type ?r @stove)
    :effect (and (forall (?o) (when (On ?o ?r) (Cooked ?o)))
                 (increase (total-cost) (PullCost)))
  )

  (:derived (On ?o1 ?o2)
    (exists (?rp) (and (RelPose ?o1 ?rp ?o2)
                       (AtRelPose ?o1 ?rp ?o2)))
  )
  (:derived (Holding ?o)
    (exists (?g) (and (Grasp ?o ?g)
                      (AtGrasp ?o ?g)))
  )
  (:derived (DoorStatus ?j ?s)
    (exists (?a) (and (AngleWithin ?j ?a ?s)
                      (AtAngle ?j ?a)))
  )

  ; https://github.mit.edu/mtoussai/KOMO-stream/blob/master/03-Caelans-pddlstreamExample/retired/domain.pddl
  ;(:derived (AtWorldPose ?o1 ?p1) (or
  ;  (and (RelPose ?o1 ?p1 @world)
  ;       (AtRelPose ?o1 ?p1 @world))
  ;  (exists (?rp ?o2 ?p2) (and (PoseKin ?o1 ?p1 ?rp ?o2 ?p2)
  ;          (AtWorldPose ?o2 ?p2) (AtRelPose ?o1 ?rp ?o2)))
  ;  (exists (?j ?a) (and (AngleKin ?o1 ?p1 ?j ?a)
  ;          (AtAngle ?j ?a))) ; TODO: could compose arbitrary chains
  ;))

  (:derived (UnsafeRelPose ?o1 ?rp1 ?s) (and (RelPose ?o1 ?rp1 ?s)
    (exists (?o2 ?rp2) (and (RelPose ?o2 ?rp2 ?s)
                            (not (CFreeRelPoseRelPose ?o1 ?rp1 ?o2 ?rp2 ?s))
                            (AtRelPose ?o2 ?rp2 ?s)))
  ))
  (:derived (UnsafeApproach ?o1 ?p1 ?g) (and (WorldPose ?o1 ?p1) (Grasp ?o1 ?g)
    (exists (?o2 ?p2) (and (WorldPose ?o2 ?p2) (Movable ?o2)
                           (not (CFreeApproachPose ?o1 ?p1 ?g ?o2 ?p2))
                           (AtWorldPose ?o2 ?p2)))
  ))
  (:derived (UnsafeATraj ?at) (and (ATraj ?at)
    (exists (?o2 ?p2) (and (WorldPose ?o2 ?p2) (Movable ?o2)
                           (not (CFreeTrajPose ?at ?o2 ?p2))
                           (AtWorldPose ?o2 ?p2)))
  ))
)