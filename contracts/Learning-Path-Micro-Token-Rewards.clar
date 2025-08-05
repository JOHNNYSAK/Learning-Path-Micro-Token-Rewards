(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-enrolled (err u101))
(define-constant err-already-enrolled (err u102))
(define-constant err-invalid-module (err u103))
(define-constant err-module-completed (err u104))
(define-constant err-insufficient-rewards (err u105))
(define-constant err-streak-broken (err u106))

(define-fungible-token learning-token)

(define-map enrollments principal (list 10 uint))
(define-map module-rewards uint uint)
(define-map completed-modules {student: principal, module-id: uint} bool)
(define-map student-streaks principal {current-streak: uint, last-completed: uint, max-streak: uint})

(define-data-var total-modules uint u10)
(define-data-var reward-per-module uint u50)

(define-public (initialize-rewards (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (ft-mint? learning-token amount contract-owner))
        (ok true)))

(define-public (enroll)
    (let ((empty-progress (list u0 u0 u0 u0 u0 u0 u0 u0 u0 u0)))
        (asserts! (is-none (map-get? enrollments tx-sender)) err-already-enrolled)
        (map-set enrollments tx-sender empty-progress)
        (ok true)))

(define-public (set-module-reward (module-id uint) (reward-amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= module-id (var-get total-modules)) err-invalid-module)
        (map-set module-rewards module-id reward-amount)
        (ok true)))

(define-public (complete-module (module-id uint))
    (let ((student-progress (unwrap! (map-get? enrollments tx-sender) err-not-enrolled))
          (base-reward (default-to (var-get reward-per-module) (map-get? module-rewards module-id)))
          (current-streak-data (default-to {current-streak: u0, last-completed: u0, max-streak: u0} (map-get? student-streaks tx-sender)))
          (new-streak (+ (get current-streak current-streak-data) u1))
          (streak-multiplier (if (<= new-streak u5) new-streak u5))
          (bonus-reward (* base-reward (- streak-multiplier u1)))
          (total-reward (+ base-reward bonus-reward))
          (new-max-streak (if (> new-streak (get max-streak current-streak-data)) new-streak (get max-streak current-streak-data))))
        (asserts! (<= module-id (var-get total-modules)) err-invalid-module)
        (asserts! (is-none (map-get? completed-modules {student: tx-sender, module-id: module-id})) err-module-completed)
        (try! (ft-transfer? learning-token total-reward contract-owner tx-sender))
        (map-set completed-modules {student: tx-sender, module-id: module-id} true)
        (map-set student-streaks tx-sender {current-streak: new-streak, last-completed: module-id, max-streak: new-max-streak})
        (ok true)))

(define-read-only (get-student-progress (student principal))
    (ok (map-get? enrollments student)))

(define-read-only (get-module-reward (module-id uint))
    (ok (map-get? module-rewards module-id)))

(define-read-only (is-module-completed (student principal) (module-id uint))
    (ok (default-to false (map-get? completed-modules {student: student, module-id: module-id}))))

(define-public (update-total-modules (new-total uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set total-modules new-total)
        (ok true)))

(define-public (update-default-reward (new-reward uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set reward-per-module new-reward)
        (ok true)))

(define-public (reset-student-streak (student principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let ((current-data (default-to {current-streak: u0, last-completed: u0, max-streak: u0} (map-get? student-streaks student))))
            (map-set student-streaks student {current-streak: u0, last-completed: u0, max-streak: (get max-streak current-data)}))
        (ok true)))

(define-read-only (get-student-streak (student principal))
    (ok (map-get? student-streaks student)))

(define-read-only (calculate-streak-bonus (base-reward uint) (streak-count uint))
    (let ((multiplier (if (<= streak-count u5) streak-count u5))
          (bonus (* base-reward (- multiplier u1))))
        (ok (+ base-reward bonus))))