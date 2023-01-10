#include "view.h"
#include "converter.h"
#include "algorithm"

constexpr EADK::Color View::k_textColor;
constexpr EADK::Color View::k_backgroundColor;

void View::drawLayout() {
  EADK::Display::pushRectUniform(EADK::Screen::Rect, k_backgroundColor);
}

void View::drawStore(Store* store) {
  for (int i = 0; i < Store::k_maxNumberOfStoredValues; i++) {
    // Erase previous value
    EADK::Rect storeRect(k_horizontalMargin, i * k_verticalMargin, std::min(k_maxNumberOfCharacters * k_characterWidth, (int)EADK::Screen::Width), k_characterHeight);
    EADK::Display::pushRectUniform(storeRect, k_backgroundColor);
    // Draw new value
    char text[k_maxNumberOfCharacters];
    Converter::Serialize(store->value(i), text, k_maxNumberOfCharacters);
    EADK::Display::drawString(text,
                              EADK::Point(k_horizontalMargin, i * k_verticalMargin),
                              true, k_textColor, k_backgroundColor);
  }
}

void View::drawInputField(const char* input) {
  // Erase previous field
  EADK::Rect fieldRect(k_horizontalMargin, Store::k_maxNumberOfStoredValues * k_verticalMargin, std::min((int)EADK::Screen::Width, k_maxNumberOfCharacters * k_characterWidth), k_characterHeight);
  EADK::Display::pushRectUniform(fieldRect, k_backgroundColor);
  // Draw new field
  EADK::Display::drawString(
      input,
      EADK::Point(k_horizontalMargin, Store::k_maxNumberOfStoredValues * k_verticalMargin),
      true, k_textColor, k_backgroundColor);
}
