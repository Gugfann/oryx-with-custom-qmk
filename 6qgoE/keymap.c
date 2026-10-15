#include QMK_KEYBOARD_H
#include "version.h"
#include "i18n.h"
#define MOON_LED_LEVEL LED_LEVEL
#ifndef ZSA_SAFE_RANGE
#define ZSA_SAFE_RANGE SAFE_RANGE
#endif

enum custom_keycodes {
  RGB_SLD = ZSA_SAFE_RANGE,
};



#define DUAL_FUNC_0 LT(4, KC_O)
#define DUAL_FUNC_1 LT(4, KC_9)
#define DUAL_FUNC_2 LT(11, KC_M)
#define DUAL_FUNC_3 LT(5, KC_F22)
#define DUAL_FUNC_4 LT(15, KC_F11)
#define DUAL_FUNC_5 LT(9, KC_F5)

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_voyager(
    KC_ESCAPE,      KC_1,           KC_2,           KC_3,           KC_4,           KC_5,                                           KC_6,           KC_7,           KC_8,           KC_9,           KC_0,           DK_PLUS,        
    KC_TAB,         LT(3, KC_Q),    KC_W,           KC_E,           KC_R,           KC_T,                                           KC_Y,           KC_U,           KC_I,           KC_O,           KC_P,           DK_ARNG,        
    KC_LEFT_SHIFT,  LT(3, KC_A),    KC_S,           KC_D,           KC_F,           KC_G,                                           KC_H,           KC_J,           KC_K,           KC_L,           DK_AE,          MT(MOD_RSFT, DK_OSTR),
    KC_LEFT_CTRL,   KC_Z,           KC_X,           KC_C,           MT(MOD_LALT, KC_V),KC_B,                                           KC_N,           KC_M,           KC_COMMA,       KC_DOT,         MT(MOD_RALT, DK_MINS),MT(MOD_RCTL, DK_QUOT),
                                                    LT(1, KC_SPACE),MT(MOD_LSFT, KC_DELETE),                                MT(MOD_RSFT, KC_ENTER),LT(2, KC_BSPC)
  ),
  [1] = LAYOUT_voyager(
    KC_ESCAPE,      KC_F1,          KC_F2,          KC_F3,          KC_F4,          KC_F5,                                          KC_F6,          KC_F7,          KC_F8,          KC_F9,          KC_F10,         KC_F11,         
    KC_TRANSPARENT, KC_TRANSPARENT, LALT(LSFT(KC_TAB)),KC_TRANSPARENT, LALT(KC_TAB),   KC_TRANSPARENT,                                 KC_7,           KC_8,           KC_9,           KC_MINUS,       KC_SLASH,       KC_F12,         
    KC_TRANSPARENT, KC_TRANSPARENT, LCTL(LSFT(KC_TAB)),KC_LEFT_GUI,    LCTL(KC_TAB),   KC_TRANSPARENT,                                 KC_4,           KC_5,           KC_6,           KC_PLUS,        KC_ASTR,        KC_BSPC,        
    KC_TRANSPARENT, DK_BSLS,        DK_LABK,        DK_RABK,        KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_1,           KC_2,           KC_3,           KC_DOT,         KC_EQUAL,       KC_ENTER,       
                                                    KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_0
  ),
  [2] = LAYOUT_voyager(
    RGB_TOG,        KC_TRANSPARENT, DK_AT,          KC_TRANSPARENT, DK_DLR,         KC_TRANSPARENT,                                 KC_TRANSPARENT, DK_LCBR,        DK_LBRC,        DK_RBRC,        DK_RCBR,        DK_PIPE,        
    KC_TRANSPARENT, KC_TRANSPARENT, DUAL_FUNC_0,    DUAL_FUNC_1,    DUAL_FUNC_2,    KC_TRANSPARENT,                                 KC_PAGE_UP,     KC_HOME,        KC_UP,          KC_END,         DK_TILD,        DK_CIRC,        
    KC_TRANSPARENT, KC_KP_0,        DUAL_FUNC_3,    DUAL_FUNC_4,    DUAL_FUNC_5,    KC_TRANSPARENT,                                 KC_PGDN,        KC_LEFT,        KC_DOWN,        KC_RIGHT,       KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_KP_0,        KC_KP_1,        KC_KP_2,        KC_KP_3,        KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
                                                    KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT
  ),
  [3] = LAYOUT_voyager(
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, NAVIGATOR_DEC_CPI,NAVIGATOR_INC_CPI,                                KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, TOGGLE_SCROLL,  DRAG_SCROLL,    QK_LLCK,        KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_MS_BTN2,     KC_MS_BTN3,     KC_MS_BTN1,     KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
                                                    KC_MS_BTN4,     KC_MS_BTN5,                                     KC_TRANSPARENT, KC_TRANSPARENT
  ),
};









bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  switch (keycode) {
  case QK_MODS ... QK_MODS_MAX:
    // Mouse and consumer keys (volume, media) with modifiers work inconsistently across operating systems,
    // this makes sure that modifiers are always applied to the key that was pressed.
    if (IS_MOUSE_KEYCODE(QK_MODS_GET_BASIC_KEYCODE(keycode))) {
      if (record->event.pressed) {
        add_mods(QK_MODS_GET_MODS(keycode));
        send_keyboard_report();
        wait_ms(2);
        register_code(QK_MODS_GET_BASIC_KEYCODE(keycode));
        return false;
      } else {
        wait_ms(2);
        del_mods(QK_MODS_GET_MODS(keycode));
      }
    }
    break;

    case DUAL_FUNC_0:
      if (record->tap.count > 0) {
        if (record->event.pressed) {
          register_code16(KC_KP_7);
        } else {
          unregister_code16(KC_KP_7);
        }
      } else {
        if (record->event.pressed) {
          register_code16(LGUI(KC_LEFT));
        } else {
          unregister_code16(LGUI(KC_LEFT));
        }  
      }  
      return false;
    case DUAL_FUNC_1:
      if (record->tap.count > 0) {
        if (record->event.pressed) {
          register_code16(KC_KP_8);
        } else {
          unregister_code16(KC_KP_8);
        }
      } else {
        if (record->event.pressed) {
          register_code16(LGUI(KC_UP));
        } else {
          unregister_code16(LGUI(KC_UP));
        }  
      }  
      return false;
    case DUAL_FUNC_2:
      if (record->tap.count > 0) {
        if (record->event.pressed) {
          register_code16(KC_KP_9);
        } else {
          unregister_code16(KC_KP_9);
        }
      } else {
        if (record->event.pressed) {
          register_code16(LGUI(KC_RIGHT));
        } else {
          unregister_code16(LGUI(KC_RIGHT));
        }  
      }  
      return false;
    case DUAL_FUNC_3:
      if (record->tap.count > 0) {
        if (record->event.pressed) {
          register_code16(KC_KP_4);
        } else {
          unregister_code16(KC_KP_4);
        }
      } else {
        if (record->event.pressed) {
          register_code16(LGUI(LSFT(KC_LEFT)));
        } else {
          unregister_code16(LGUI(LSFT(KC_LEFT)));
        }  
      }  
      return false;
    case DUAL_FUNC_4:
      if (record->tap.count > 0) {
        if (record->event.pressed) {
          register_code16(KC_KP_5);
        } else {
          unregister_code16(KC_KP_5);
        }
      } else {
        if (record->event.pressed) {
          register_code16(LGUI(KC_DOWN));
        } else {
          unregister_code16(LGUI(KC_DOWN));
        }  
      }  
      return false;
    case DUAL_FUNC_5:
      if (record->tap.count > 0) {
        if (record->event.pressed) {
          register_code16(KC_KP_6);
        } else {
          unregister_code16(KC_KP_6);
        }
      } else {
        if (record->event.pressed) {
          register_code16(LGUI(LSFT(KC_RIGHT)));
        } else {
          unregister_code16(LGUI(LSFT(KC_RIGHT)));
        }  
      }  
      return false;
    case RGB_SLD:
      if (record->event.pressed) {
        rgblight_mode(1);
      }
      return false;
  }
  return true;
}
