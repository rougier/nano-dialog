;;; nano-dialog.el --- Native dialog popups -*- lexical-binding: t -*-

;; Copyright (C) 2023 Nicolas P. Rougier

;; Maintainer: Nicolas P. Rougier <Nicolas.Rougier@inria.fr>
;; URL: https://github.com/rougier/nano-dialog
;; Version: 0.2
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This package provide native dialog boxes with a header, a content
;; and a set of configurable buttons.
;;
;;; Usage:
;;
;; (defun click (frame label)
;;   (message "You have clicked on %s" label))
;; (add-hook 'nano-dialog-button-hook #'click)
;;
;; (nano-dialog "*nano-dialog*"
;;              :title "[I] NANO Dialog"
;;              :buttons '("OK" "CANCEL"))
;;
;; NEWS:
;;
;; Version 0.2
;; - Added button hook
;; - Added delete hook
;; - Added text button text option
;;
;; Version 0.1
;; - First version

;;; Code
(require 'svg-lib)
(require 'tooltip)

;; See https://material.io/design/color/the-color-system.html
(defconst nano-dialog--colors
  '((red         . ("#FFEBEE" "#FFCDD2" "#EF9A9A" "#E57373" "#EF5350"
                    "#F44336" "#E53935" "#D32F2F" "#C62828" "#B71C1C"))
    (pink        . ("#FCE4EC" "#F8BBD0" "#F48FB1" "#F06292" "#EC407A"
                    "#E91E63" "#D81B60" "#C2185B" "#AD1457" "#880E4F"))
    (purple      . ("#F3E5F5" "#E1BEE7" "#CE93D8" "#BA68C8" "#AB47BC"
                    "#9C27B0" "#8E24AA" "#7B1FA2" "#6A1B9A" "#4A148C"))
    (deep-purple . ("#EDE7F6" "#D1C4E9" "#B39DDB" "#9575CD" "#7E57C2"
                    "#673AB7" "#5E35B1" "#512DA8" "#4527A0" "#311B92"))
    (indigo      . ("#E8EAF6" "#C5CAE9" "#9FA8DA" "#7986CB" "#5C6BC0"
                    "#3F51B5" "#3949AB" "#303F9F" "#283593" "#1A237E"))
    (blue        . ("#E3F2FD" "#BBDEFB" "#90CAF9" "#64B5F6" "#42A5F5"
                    "#2196F3" "#1E88E5" "#1976D2" "#1565C0" "#0D47A1"))
    (light-blue  . ("#E1F5FE" "#B3E5FC" "#81D4FA" "#4FC3F7" "#29B6F6"
                    "#03A9F4" "#039BE5" "#0288D1" "#0277BD" "#01579B"))
    (cyan        . ("#E0F7FA" "#B2EBF2" "#80DEEA" "#4DD0E1" "#26C6DA"
                    "#00BCD4" "#00ACC1" "#0097A7" "#00838F" "#006064"))
    (teal        . ("#E0F2F1" "#B2DFDB" "#80CBC4" "#4DB6AC" "#26A69A"
                    "#009688" "#00897B" "#00796B" "#00695C" "#004D40"))
    (green       . ("#E8F5E9" "#C8E6C9" "#A5D6A7" "#81C784" "#66BB6A"
                    "#4CAF50" "#43A047" "#388E3C" "#2E7D32" "#1B5E20"))
    (light-green . ("#F1F8E9" "#DCEDC8" "#C5E1A5" "#AED581" "#9CCC65"
                    "#8BC34A" "#7CB342" "#689F38" "#558B2F" "#33691E"))
    (lime        . ("#F9FBE7" "#F0F4C3" "#E6EE9C" "#DCE775" "#D4E157"
                    "#CDDC39" "#C0CA33" "#AFB42B" "#9E9D24" "#827717"))
    (yellow      . ("#FFFDE7" "#FFF9C4" "#FFF59D" "#FFF176" "#FFEE58"
                    "#FFEB3B" "#FDD835" "#FBC02D" "#F9A825" "#F57F17"))
    (amber       . ("#FFF8E1" "#FFECB3" "#FFE082" "#FFD54F" "#FFCA28"
                    "#FFC107" "#FFB300" "#FFA000" "#FF8F00" "#FF6F00"))
    (orange      . ("#FFF3E0" "#FFE0B2" "#FFCC80" "#FFB74D" "#FFA726"
                    "#FF9800" "#FB8C00" "#F57C00" "#EF6C00" "#E65100"))
    (deep-orange . ("#FBE9E7" "#FFCCBC" "#FFAB91" "#FF8A65" "#FF7043"
                    "#FF5722" "#F4511E" "#E64A19" "#D84315" "#BF360C"))
    (brown       . ("#EFEBE9" "#D7CCC8" "#BCAAA4" "#A1887F" "#8D6E63"
                    "#795548" "#6D4C41" "#5D4037" "#4E342E" "#3E2723"))
    (grey        . ("#FAFAFA" "#F5F5F5" "#EEEEEE" "#E0E0E0" "#BDBDBD"
                    "#9E9E9E" "#757575" "#616161" "#424242" "#212121"))
    (blue-grey   . ("#ECEFF1" "#CFD8DC" "#B0BEC5" "#90A4AE" "#78909C"
                    "#607D8B" "#546E7A" "#455A64" "#37474F" "#263238"))))

(defun nano-dialog-color (hue level)
  "Get HUE color with given LEVEL"
  
  (nth level (alist-get hue nano-dialog--colors)))

(defvar nano-dialog-button-hook nil
  "Normal hook ran after a button has been pressed")

(defvar nano-dialog-delete-hook nil
  "Normal hook ran just before deleting a dialog")

(defcustom nano-dialog-child-frame t
  "If t, dialog will be a child frame of the current selected frame.")

(defcustom nano-dialog-svg-button t
  "If t, dialog will use SVG buttons instead of text button.")

(defcustom nano-dialog-transient t
  "If t, dialog will be deleted as soon as it losts focus.")

(defcustom nano-dialog-width 72
  "Dialog frame width (characters)")

(defcustom nano-dialog-height 8
  "Dialog frame height (characters)")

(defcustom nano-dialog-x-position 0.5
  "Dialog frame position (relative)")

(defcustom nano-dialog-y-position 0.5
  "Dialog position (relative)")

(defcustom nano-dialog-margin '(2 . 2)
  "Dialog window margin (left & right, characters)")

(defcustom nano-dialog-header-padding '(0.50 . 0.50)
  "Header padding (top & bottom, characters)")

(defcustom nano-dialog-footer-padding '(0.75 . 0.75)
  "Footer padding (top & bottom, characters)")

(defface nano-dialog-default-face
  `((t :foreground ,(face-foreground 'default)
       :background ,(nano-dialog-color 'blue-grey 0)
       :inherit bold
       :box (:line-width 1
             :color ,(face-foreground 'default))))
  "Dialog default face.")

(defface nano-dialog-info-face
  `((t :foreground "black"
       :background ,(nano-dialog-color 'indigo 0)
       :inherit bold
       :box (:line-width 1
             :color ,(nano-dialog-color 'indigo 3))))
  "Dialog info face.")

(defface nano-dialog-question-face
  `((t :foreground "black"
       :background ,(nano-dialog-color 'purple 1)
       :inherit bold
       :box (:line-width 1
             :color ,(nano-dialog-color 'purple 5))))
  "Dialog question face.")

(defface nano-dialog-alert-face
  `((t :foreground "black"
       :background ,(nano-dialog-color 'amber 1)
       :inherit bold
       :box (:line-width 1
             :color ,(face-foreground 'default))))
  "Dialog altert face.")

(defface nano-dialog-success-face
  `((t :foreground "black"
       :background ,(nano-dialog-color 'light-green 1)
       :inherit bold
       :box (:line-width 1
             :color ,(nano-dialog-color 'light-green 5))))
  "Dialog success face.")

(defface nano-dialog-failure-face
  `((t :foreground "white"
       :background ,(nano-dialog-color 'red 5)
       :inherit bold
       :box (:line-width 1
             :color ,(nano-dialog-color 'red 9))))
  "Dialog failure face.")

(defface nano-dialog-warning-face
  `((t :foreground "black"
       :background ,(nano-dialog-color 'orange 1)
       :inherit bold
       :box (:line-width 1
             :color ,(nano-dialog-color 'orange 5))))
  "Dialog warning face.")

(defface nano-dialog-error-face
  `((t :foreground "white"
       :background ,(nano-dialog-color 'red 5)
       :inherit bold
       :box (:line-width 1
             :color ,(nano-dialog-color 'red 9))))
  "Dialog error face.")

(defface nano-dialog-button-active-face
  `((t :foreground ,(face-foreground 'default)
       :background ,(face-background 'default)
       :box (:line-width 2
             :color ,(face-foreground 'default)
             :style none)))
  "Active button face")

(defface nano-dialog-button-inactive-face
  `((t :foreground ,(face-foreground 'default)
       :background ,(face-background 'default))
       :box (:line-width 2
             :color ,(face-foreground 'default)
             :style none))
  "Inactive button face")

(defface nano-dialog-button-highlight-face
  `((t :foreground ,(face-background 'default)
       :background ,(face-foreground 'default)
       :weight semibold))
  "Highlight button face")

(defface nano-dialog-button-pressed-face
  `((t :foreground ,(face-background 'default nil t)
       :background ,(face-foreground 'default nil t)))
  "Pressed button face")

(defun nano-dialog--stroke-width (face)
  "Extract the line width of the box for the given FACE."
  
  (let* ((box (face-attribute face ':box nil 'default))
         (width (plist-get box ':line-width)))
      (cond ((integerp width) width)
            ((consp width) (car width))
            (t 0))))

(defun nano-dialog--stroke-color (face)
  "Extract the line color of the box for the given FACE."
  
  (let* ((box (face-attribute face ':box))
         (color (plist-get box ':color)))
    (cond ((stringp color) color)
          (t (face-foreground face nil 'default)))))

(cl-defun nano-dialog--make-frame
    (buffer &key
            (title          nil)
            (buttons        nil)
            (name           nil)
            (face          'nano-dialog-default-face)
            (transient      nano-dialog-transient)
            (child-frame    nano-dialog-child-frame)
            (x              nano-dialog-x-position)
            (y              nano-dialog-y-position)
            (width          nano-dialog-width)
            (height         nano-dialog-height)
            (margin         nano-dialog-margin))
    "Build the frame for BUFFER, applying style elements."
  
  (let* ((border-color (nano-dialog--stroke-color face))
         (border-width (max 1 (nano-dialog--stroke-width face)))

         ;; The given height is for the buffer. Consequently, we add
         ;; padding to the height such as to guarantee buffer height.
         ;; If header face is bigger, this code would need to be
         ;; adapted.
         ;; When no title, header is an empty line without padding
         ;; When no buttons, footer is an empty line without padding
         (height (floor (+ height 1
                           1
                           (if title (car nano-dialog-header-padding) 0)
                           (if title (cdr nano-dialog-header-padding) 0)
                           1
                           (if buttons (car nano-dialog-footer-padding) 0)
                           (if buttons (cdr nano-dialog-footer-padding) 0))))
         (parent (selected-frame))
         (frame (make-frame `((name . ,name)
                              (type . nano-dialog)
                              (parent-frame . ,(if child-frame parent nil))
                              (alpha . 100)
                              (margin . ,margin)
                              (transient . ,transient)
                              (width . ,width)
                              (height . ,height)
                              (internal-border-width . ,border-width)
                              (visibility . nil)
                              (minibuffer . nil)))))
    (if child-frame
        (progn
          (set-face-background 'child-frame-border border-color frame)
          (modify-frame-parameters frame `((top . ,y) (left . ,x))))
      (set-face-background 'internal-border border-color frame))
    (select-frame-set-input-focus frame)
    (switch-to-buffer buffer)
    (add-to-list 'window-buffer-change-functions
                 #'nano-dialog--apply-margin)
    (set-window-margins (get-buffer-window) (car margin) (cdr margin))
    (make-frame-visible frame)
    (set-window-dedicated-p (get-buffer-window) t)
    (add-function :after after-focus-change-function #'nano-dialog-delete)
    frame))

(defun nano-dialog--apply-margin (&rest args)
  "Apply margin to the dialog window"
  
  (when-let* ((frame (selected-frame))
              (type (frame-parameter frame 'type))
              (margin (frame-parameter frame 'margin)))
    (when (eq type 'nano-dialog)
      (set-window-margins (get-buffer-window)
                          (car margin) (cdr margin)))))

(cl-defun nano-dialog--make-header
    (buffer &key
            (title          nil)
            (buttons        nil)
            (name           nil)
            (face          'nano-dialog-default-face)
            (transient      nano-dialog-transient)
            (child-frame    nano-dialog-child-frame)
            (x              nano-dialog-x-position)
            (y              nano-dialog-y-position)
            (width          nano-dialog-width)
            (height         nano-dialog-height)
            (margin         nano-dialog-margin))
  "Build the header for BUFFER, applying style elements."
  
  (with-current-buffer buffer
    (if (stringp title)
        (setq-local header-line-format
           `(:eval
             (concat
              (propertize (make-string ,(car margin) ? )
                          'display '(raise ,(car nano-dialog-header-padding)))
              ,title
              (propertize " " 'display '(raise ,(- (cdr nano-dialog-header-padding))))
              (propertize " " 'display `(space :align-to (- right 1)))
              (propertize "✕"
                          'pointer 'hand
                          'keymap (let ((map (make-sparse-keymap)))
                                    (define-key map [header-line mouse-1]
                                      (lambda ()
                                        (interactive)
                                        (nano-dialog-delete t)))
                                    map)))))
        (setq-local header-line-format ""))
      (if title
          (face-remap-set-base 'header-line
                               `(:inherit ,(face-attribute face ':inherit)
                                 :foreground ,(face-foreground face)
                                 :background ,(face-background face)))
        (face-remap-set-base 'header-line
                             `(:inherit ,(face-attribute face ':inherit)
                               :foreground ,(face-foreground face)
                               :background ,(face-background 'default))))))

(defun nano-dialog--make-text-button (label foreground background)
  "Make a text button from LABEL, FOREROUND color and BACKGROUND color"

  (let* ((label (concat " " label " "))
         ;; We compensate the footer padding with an irregular outer
         ;; box around label (vertical border with a default
         ;; background color). If this is not made the background color
         ;; is the height of the modeline which is not very aesthetic.
         (padding (floor (/ (* (frame-char-height)
                               (+ (car nano-dialog-footer-padding)
                                  (cdr nano-dialog-footer-padding))) 2))))
    (propertize label
                'face `(:foreground ,foreground
                        :background ,background
                        :box (:line-width (0 . ,padding)
                                          :color ,(face-background 'default))))))

(defun nano-dialog--make-svg-button (label foreground background stroke)
  "Make a svg button from LABEL, FOREROUND color and BACKGROUND color"

  (propertize (concat label " ")
              'display (svg-lib-tag label nil :foreground foreground
                                              :background background
                                              :stroke stroke
                                              :padding 1
                                              :margin 0)))

(defun nano-dialog--make-button (button &optional use-svg)
  "Make a svg button from BUTTON that is a cons (label . state)."

  (let* ((label (car button))
         (state (cdr button))
         (face (cond ((eq state 'highlight) 'nano-dialog-button-highlight-face)
                     ((eq state 'inactive)  'nano-dialog-button-inactive-face)
                     ((eq state 'pressed)   'nano-dialog-button-pressed-face)
                     (t                     'nano-dialog-button-active-face)))
         (foreground (face-foreground face nil 'default))
         (background (face-background face nil 'default))
         (stroke (nano-dialog--stroke-width face))
         (button (if use-svg
                     (nano-dialog--make-svg-button label foreground background stroke)
                   (nano-dialog--make-text-button label foreground background))))
    (propertize button
                'pointer 'hand
                'label label
                'keymap (let ((map (make-sparse-keymap)))
                          (define-key map [mode-line mouse-1]
                            `(lambda ()
                               (interactive)
                               (nano-dialog--button-pressed ,label)))
                          map)
                'help-echo `(lambda (window object pos)
                              (nano-dialog--update-button-state ,label 'highlight)))))

(defun nano-dialog--button-pressed (label)
  "Handle pressed button event"

  (nano-dialog--update-button-state label 'active)
  (dolist (hook nano-dialog-button-hook)
    (funcall hook (selected-frame) label))
  (delete-frame))

(defun nano-dialog--button-released (label)
  "Handle released button event"

  ;; NOT USED: Problem is that due to tooltip hack, the update
  ;; function is called just before the release button event which
  ;; result in the button not being updated properly. We thus need to
  ;; check if the cursor is on top of a button.
  (let ((buttons (frame-parameter nil 'buttons))
        (state))
    (dolist (button buttons)
      (let ((button-label (car button))
            (button-state (cdr button)))
        (when (string-equal button-label label)
          (setq state button-state))
        (unless (eq button-state 'inactive)
          (setcdr button 'active))))
    (modify-frame-parameters nil `((buttons . ,buttons)))))

(defun nano-dialog--reset-button-state (&rest args)
  "Reset the state of the buttons."

  (let ((buttons (frame-parameter nil 'buttons)))
    (dolist (button buttons)
      (let ((button-state (cdr button)))
        (unless (or (eq button-state 'inactive)
                    (eq button-state 'pressed)
                    (eq button-state 'pressed-outside))
          (setcdr button 'active))
        (when (eq button-state 'pressed)
          (setcdr button 'pressed-outside))))
      (modify-frame-parameters nil `((buttons . ,buttons))))
  (force-mode-line-update))

(defun nano-dialog--update-button-state (label state)
  "Update the state of the button LABEL with new STATE and update
other button states."

  (let ((buttons (frame-parameter nil 'buttons)))
    (dolist (button buttons)
      (let ((button-label (car button))
            (button-state (cdr button)))
        (unless (eq button-state 'inactive)
          (if (string-equal button-label label)
              (if (or (eq button-state 'pressed-outside)
                      (eq button-state 'pressed))
                  (setcdr button 'pressed)
                (setcdr button state))
            (if (or (eq button-state 'pressed-outside)
                    (eq button-state 'pressed))
                (setcdr button 'pressed-outside)
              (setcdr button 'active))))))
    
      (modify-frame-parameters nil `((buttons . ,buttons))))
  (force-mode-line-update))

;; (defun nano-dialog--make-footer (buffer &rest args)
(cl-defun nano-dialog--make-footer
    (buffer &key
            (title          nil)
            (buttons        nil)
            (name           nil)
            (face          'nano-dialog-default-face)
            (transient      nano-dialog-transient)
            (child-frame    nano-dialog-child-frame)
            (x              nano-dialog-x-position)
            (y              nano-dialog-y-position)
            (width          nano-dialog-width)
            (height         nano-dialog-height)
            (margin         nano-dialog-margin))
  "Build the footer for BUFFER, applying style elements."

  ;; We store the buttons state inside the frame such as to be able
  ;; to update their state later
  (if buttons
      (progn
        (let ((buttons (mapcar (lambda (label)
                                 (cons label 'active))
                               buttons)))
          (modify-frame-parameters (selected-frame)
                                   `((buttons . ,buttons)))
          (setq-local mode-line-format
              `(:eval
                 (let* ((buttons (frame-parameter nil 'buttons))
                        (buttons (if nano-dialog-svg-button
                                     (mapconcat (lambda (button)
                                                  (nano-dialog--make-button button t))
                                                buttons " ")
                                   (mapconcat (lambda (button)
                                                (nano-dialog--make-button button nil))
                                              buttons " "))))
                   (concat
                    (propertize " " 'display '(raise ,(+ (car nano-dialog-footer-padding))))
                    (propertize " " 'display '(raise ,(- (cdr nano-dialog-footer-padding))))
                    (propertize " " 'display `(space :align-to (- right ,(length buttons))))
                    buttons))))))
    (progn
      (modify-frame-parameters (selected-frame) '((buttons . nil)))
      (setq-local mode-line-format "")))

    (face-remap-set-base 'mode-line
                         `(:foreground ,(face-foreground face)
                           :background ,(face-background 'default)
                           :family ,(face-attribute face :family t 'default)
                           :weight ,(face-attribute face :weight t 'default)
                           :height ,(face-attribute 'default :height)))
    (face-remap-set-base 'mode-line-inactive
                         `(:foreground ,(face-foreground face)
                           :background ,(face-background 'default)
                           :family ,(face-attribute face :family t 'default)
                           :weight ,(face-attribute face :weight t 'default)
                           :height ,(face-attribute 'default :height))))

(defun nano-dialog-delete (&optional force)
  "Delete the dialog frame if not focused or FORCE is t."
  
  ;; Focus change event are not really consistent and it may happen
  ;; that several events are sent one after the other. On OSX, it
  ;; seems that spurious events can be detected by checking if any
  ;; frame has focus. If none has focus, we label the event as not
  ;; valid. See also: https://emacs.stackexchange.com/questions/62783

  ;; Check if at least one frame has focus
  (let ((valid nil)
        (frame nil))
    (dolist (_frame (frame-list))
      (when (eq (frame-parameter _frame 'type) 'nano-dialog)
        (setq frame _frame))
      (setq valid (or valid (frame-focus-state _frame))))

   ;; If at least one frame has focus, we kill the dialog if it was
   ;; focused or if FORCE is t. 
    (when (or force
              (and valid
               (framep frame)
               (frame-live-p frame)
               (frame-visible-p frame)
               (frame-parameter frame 'transient)
               (not (frame-focus-state frame))))
      (dolist (hook nano-dialog-delete-hook)
        (funcall hook frame))
      (delete-frame frame))))

(defun nano-dialog (&optional buffer &rest args)
  "Build and show a new dialog showing BUFFER.

  Args can be:

  :title          ;; Dialog title (string)
  :buttons        ;; Labels for dialog SVG buttons (list of string)
  :face           ;; Dialog face (face)
  :transient      ;; Dialog transient property (bool)
  :child-frame    ;; Whether dialog is a child frame (bool)
  :x              ;; Dialog x position (int or float)
  :y              ;; Dialog y position (int or float)
  :width          ;; Dialog width (int)
  :height         ;; Dialog height (int)
  :margin         ;; Dialog window margin (cons int int)"
  
  (let* ((buffer (or buffer "*nano-dialog*"))
         (frame (apply #'nano-dialog--make-frame buffer args)))
    (apply #'nano-dialog--make-header buffer args)
    (apply #'nano-dialog--make-footer buffer args)
    (tooltip-mode t)
    (setq tooltip-delay 0)
    (advice-add 'tooltip-hide :before #'nano-dialog--reset-button-state)
    frame))

(defun nano-dialog-info (&optional buffer &rest args)
  "Build and show a new info dialog showing BUFFER.
 See nano-dialog for options"
  
  (apply #'nano-dialog buffer
         :face 'nano-dialog-info-face args))

(defun nano-dialog-alert (&optional buffer  &rest args)
  "Build and show a new alert dialog showing BUFFER.
 See nano-dialog for options"

  (apply #'nano-dialog buffer
         :face 'nano-dialog-alert-face args))

(defun nano-dialog-question (&optional buffer &rest args)
  "Build and show a new question dialog showing BUFFER.
 See nano-dialog for options"

  (apply #'nano-dialog buffer
         :face 'nano-dialog-question-face args))

(defun nano-dialog-warning (&optional buffer &rest args)
  "Build and show a new warning dialog showing BUFFER.
 See nano-dialog for options"

  (apply #'nano-dialog buffer
         :face 'nano-dialog-warning-face args))

(defun nano-dialog-error (&optional buffer &rest args)
  "Build and show a new error dialog showing BUFFER.
 See nano-dialog for options"

  (apply #'nano-dialog buffer
         :face 'nano-dialog-error-face args))

(defun nano-dialog-success (&optional buffer &rest args)
  "Build and show a new success dialog showing BUFFER.
 See nano-dialog for options"

  (apply #'nano-dialog buffer
         :face 'nano-dialog-success-face args))
 
(defun nano-dialog-failure (&optional buffer &rest args)
  "Build and show a new failure dialog showing BUFFER.
 See nano-dialog for options"

  (apply #'nano-dialog buffer
         :face 'nano-dialog-failure-face args))

(provide 'nano-dialog)
;;; nano-dialog.el ends here

;; (nano-dialog-info     "*nano-dialog*" :title "􁌴 Info")
;; (nano-dialog-question "*nano-dialog*" :title "􁌶 Question")
;; (nano-dialog-success  "*nano-dialog*" :title "􀿋 Success")
;; (nano-dialog-warning  "*nano-dialog*" :title "􀌬 Warning")
;; (nano-dialog-failure  "*nano-dialog*" :title "􀌬 Failure")
;; (nano-dialog-error    "*nano-dialog*" :title "􀌬 Error")



