#ifndef THREAD_CALLER_H_
#define THREAD_CALLER_H_

#include "Callback.h"

#include <string>

/** This class is used to simulate a call from C++.
 */
class Caller {
public:
  Callback *clbk_;

  Caller(Callback *c=NULL)
    : clbk_(c) {}

  /** Simulate a call from C++
   */
  void call(const std::string &msg) {
    if (clbk_) {
      clbk_->call(msg);
    }
  }

  /** Simulate delete from C++
   */
  void destroyCallback() {
    if (clbk_) {
      delete clbk_;
      clbk_ = NULL;
    }
  }
};

#endif // THREAD_CALLER_H_


