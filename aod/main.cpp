/*
 * Switches the panel into its hardware AOD mode while the screen dozes.
 *
 * The mi_disp driver only enters the low-power AOD mode (and drops to the DDIC refresh rate) when
 * doze_brightness is written; stock does this from MIUI. The sensor hub reports xiaomi.sensor.aod
 * when the display dozes and when the ambient light changes, so we map its value to
 * doze_brightness: 1 = high (HBM), 2 = low (LBM). Leaving doze resets it in the driver.
 *
 * It also turns on the touch IC double tap gesture (touchfeature mode 14), which stock enables
 * from MIUI settings; without it xiaomi.sensor.dbtap never fires for double tap to wake.
 */

#define LOG_TAG "xiaomi-aod-notifier"

#include <aidl/android/frameworks/sensorservice/BnEventQueueCallback.h>
#include <aidl/android/frameworks/sensorservice/ISensorManager.h>
#include <android-base/file.h>
#include <android-base/logging.h>
#include <android/binder_ibinder.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include <atomic>
#include <chrono>
#include <string>
#include <thread>

using aidl::android::frameworks::sensorservice::BnEventQueueCallback;
using aidl::android::frameworks::sensorservice::IEventQueue;
using aidl::android::frameworks::sensorservice::ISensorManager;
using aidl::android::hardware::sensors::Event;
using aidl::android::hardware::sensors::SensorInfo;

namespace {

constexpr char kAodSensorType[] = "xiaomi.sensor.aod";
constexpr char kDozeBrightnessPath[] = "/sys/class/mi_display/disp-DSI-0/doze_brightness";
constexpr char kDozeBrightnessHigh[] = "1";
constexpr char kDozeBrightnessLow[] = "2";

constexpr char kTouchFeatureInstance[] = "vendor.xiaomi.hw.touchfeature.ITouchFeature/default";
constexpr char kTouchFeatureDescriptor[] = "vendor.xiaomi.hw.touchfeature.ITouchFeature";
// ITouchFeature.setTouchMode(int touchId, int mode, int value) is the 9th method.
constexpr transaction_code_t kSetTouchMode = FIRST_CALL_TRANSACTION + 8;
constexpr int32_t kTouchDoubleTapMode = 14;

void* onCreate(void* args) {
    return args;
}
void onDestroy(void*) {}
binder_status_t onTransact(AIBinder*, transaction_code_t, const AParcel*, AParcel*) {
    return STATUS_UNKNOWN_TRANSACTION;
}

// Calls setTouchMode without the generated stubs, whose library name clashes with the stock one.
void enableDoubleTapGesture() {
    static AIBinder_Class* clazz =
            AIBinder_Class_define(kTouchFeatureDescriptor, onCreate, onDestroy, onTransact);
    ndk::SpAIBinder binder(AServiceManager_checkService(kTouchFeatureInstance));
    if (binder.get() == nullptr || !AIBinder_associateClass(binder.get(), clazz)) {
        LOG(WARNING) << "touchfeature unavailable";
        return;
    }
    AParcel* in = nullptr;
    if (AIBinder_prepareTransaction(binder.get(), &in) != STATUS_OK) return;
    AParcel_writeInt32(in, 0);
    AParcel_writeInt32(in, kTouchDoubleTapMode);
    AParcel_writeInt32(in, 1);
    AParcel* out = nullptr;
    binder_status_t status = AIBinder_transact(binder.get(), kSetTouchMode, &in, &out, 0);
    if (status != STATUS_OK) LOG(WARNING) << "setTouchMode failed: " << status;
    AParcel_delete(out);
}

float eventValue(const Event& event) {
    switch (event.payload.getTag()) {
        case Event::EventPayload::scalar:
            return event.payload.get<Event::EventPayload::scalar>();
        case Event::EventPayload::data:
            return event.payload.get<Event::EventPayload::data>().values[0];
        default:
            return -1;
    }
}

// Doze'a girisde cekirdek dogrudan HBM'e aliyor ve sensor olayi gelmese bile orada kaliyor.
// Bu yuzden LBM'i periyodik olarak zorluyoruz; parlak ortam olayi (3) son 120 sn icindeyse
// HBM'e dokunmuyoruz.
std::atomic<int64_t> gLastBrightEventMs{0};
// Yalnizca doze penceresinde yaziyoruz; uyanikken dugume dokunmak
// kilit acilisinda paneli kisiyordu.
std::atomic<bool> gDozing{false};

void writeDozeBrightness(const char* mode) {
    if (!android::base::WriteStringToFile(mode, kDozeBrightnessPath)) {
        PLOG(ERROR) << "failed to write " << kDozeBrightnessPath;
    }
}

// Kernel doze'a girerken kendi HIGH yazimini yapabiliyor; LOW'u kisa bir pencere icinde
// birkac kez tekrarliyoruz. SINIRSIZ DONGU YOK: sensorun uyanis olayi (5) gelmediginde
// gDozing true kaliyor ve dongu uyanikken LOW yazip paneli ANINDA kisiyordu.
void reassertLowBrightness() {
    for (int i = 0; i < 3; i++) {
        std::this_thread::sleep_for(std::chrono::milliseconds(i == 0 ? 300 : 900));
        if (!gDozing.load()) return;
        std::string cur;
        if (android::base::ReadFileToString(kDozeBrightnessPath, &cur)) {
            while (!cur.empty() && (cur.back() == '\n' || cur.back() == ' ')) cur.pop_back();
            if (cur == kDozeBrightnessLow) continue;  // zaten LBM
        }
        writeDozeBrightness(kDozeBrightnessLow);
    }
}

class AodCallback : public BnEventQueueCallback {
  public:
    ndk::ScopedAStatus onEvent(const Event& event) override {
        const int value = static_cast<int>(eventValue(event));
        // 4 = doze'a giris, 5 = uyanis.
        if (value == 4) {
            gDozing.store(true);
        } else if (value == 5) {
            gDozing.store(false);
        }
        // 3 is reported in bright surroundings; everything else (dark/normal) gets the low mode.
        const char* mode = value == 3 ? kDozeBrightnessHigh : kDozeBrightnessLow;
        if (value == 3) {
            gLastBrightEventMs.store(std::chrono::duration_cast<std::chrono::milliseconds>(
                                             std::chrono::steady_clock::now().time_since_epoch())
                                             .count());
        }
        LOG(INFO) << "aod event " << value << " (dozing=" << gDozing.load()
                  << ") -> " << (gDozing.load() ? mode : "yazma yok");
        enableDoubleTapGesture();
        // Uyanikken dugume yazmak paneli kisiyordu: sadece doze penceresinde yaz.
        if (gDozing.load()) {
            writeDozeBrightness(mode);
            if (value != 3) std::thread(reassertLowBrightness).detach();
        }
        return ndk::ScopedAStatus::ok();
    }
};

}  // namespace

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(1);
    ABinderProcess_startThreadPool();

    const std::string instance = std::string(ISensorManager::descriptor) + "/default";
    auto manager = ISensorManager::fromBinder(
            ndk::SpAIBinder(AServiceManager_waitForService(instance.c_str())));
    if (!manager) {
        LOG(ERROR) << "no " << instance;
        return 1;
    }

    std::vector<SensorInfo> sensors;
    if (!manager->getSensorList(&sensors).isOk()) {
        LOG(ERROR) << "getSensorList failed";
        return 1;
    }
    int32_t handle = -1;
    for (const auto& sensor : sensors) {
        if (sensor.typeAsString == kAodSensorType &&
            (sensor.flags & SensorInfo::SENSOR_FLAG_BITS_WAKE_UP)) {
            handle = sensor.sensorHandle;
            break;
        }
    }
    if (handle < 0) {
        LOG(ERROR) << "no wakeup " << kAodSensorType << " sensor";
        return 1;
    }

    std::shared_ptr<IEventQueue> queue;
    auto callback = ndk::SharedRefBase::make<AodCallback>();
    if (!manager->createEventQueue(callback, &queue).isOk() ||
        !queue->enableSensor(handle, 0 /* samplingPeriodUs */, 0 /* maxBatchReportLatencyUs */)
                 .isOk()) {
        LOG(ERROR) << "failed to enable " << kAodSensorType;
        return 1;
    }
    LOG(INFO) << "listening on " << kAodSensorType << " (handle " << handle << ")";
    enableDoubleTapGesture();

    ABinderProcess_joinThreadPool();
    return 1;
}
