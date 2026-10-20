/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-FileCopyrightText: Paranoid Android
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "UdfpsHandler.xiaomi_sm8750"

#include <aidl/android/hardware/biometrics/fingerprint/AcquiredInfo.h>
#include <android-base/logging.h>
#include <android-base/unique_fd.h>

#include <fstream>
#include <cstddef>
#include <atomic>

#include "UdfpsHandler.h"

static_assert(offsetof(fingerprint_device_t, extCmd) == 0xf0,
              "xuanyuan QCOM ultrasonic HAL requires fingerprint V2 layout");

#define COMMAND_FOD_PRESS_STATUS 1
#define COMMAND_FOD_PRESS_X 2
#define COMMAND_FOD_PRESS_Y 3
#define PARAM_FOD_PRESSED 1
#define PARAM_FOD_RELEASED 0

using ::aidl::android::hardware::biometrics::fingerprint::AcquiredInfo;

namespace {

template <typename T>
static void set(const std::string& path, const T& value) {
    std::ofstream file(path);
    file << value;
}

}  // anonymous namespace

class SM8750UdfpsHandler : public UdfpsHandler {
  public:
    void init(fingerprint_device_t* device) {
        mDevice = device;
    }

    void onFingerDown(uint32_t x, uint32_t y, float /*minor*/, float /*major*/) {
        LOG(INFO) << __func__ << mFingerDown.load() << x << y; if (mFingerDown.exchange(true)) { LOG(WARNING) << __func__; mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_X, 0); mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_Y, 0); mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_STATUS, PARAM_FOD_RELEASED); }
        LOG(DEBUG) << __func__ << "x: " << x << ", y: " << y;
        mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_X, x);
        mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_Y, y);
        mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_STATUS, PARAM_FOD_PRESSED);
    }

    void onFingerUp() {
        LOG(INFO) << __func__ << mFingerDown.load(); if (!mFingerDown.exchange(false)) return;
        LOG(DEBUG) << __func__;
        mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_X, 0);
        mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_Y, 0);
        mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_STATUS, PARAM_FOD_RELEASED);
    }

    void onAcquired(int32_t result, int32_t vendorCode) {
        LOG(DEBUG) << __func__ << " result: " << result << " vendorCode: " << vendorCode;
        // QCOM V2 delivers acquired callbacks from its own pointer handling.
        // Sending a pointer-up here re-enters that HAL while it is notifying us.
        // Only framework pointer-up/cancel should release the touch.
    }

    void cancel() {
        LOG(INFO) << __func__;
        onFingerUp();
    }

  private:
    fingerprint_device_t* mDevice;
    std::atomic_bool mFingerDown{false};
};

static UdfpsHandler* create() {
    return new SM8750UdfpsHandler();
}

static void destroy(UdfpsHandler* handler) {
    delete handler;
}

extern "C" UdfpsHandlerFactory UDFPS_HANDLER_FACTORY = {
        .create = create,
        .destroy = destroy,
};
