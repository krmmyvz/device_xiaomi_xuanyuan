#pragma once

#include <binder/IInterface.h>
#include <binder/SafeInterface.h>
#include <utils/Errors.h>
#include <utils/RefBase.h>

#include <cstdint>

namespace android {

class BufferItem;
class FrameEventHistoryDelta;
struct NewFrameEventsEntry;

// ABI-compatible declaration from before IConsumerListener's binder transport
// was removed. This is private to the compatibility library.
class ConsumerListener : public virtual RefBase {
public:
    ConsumerListener() {}
    virtual ~ConsumerListener();

    virtual void onDisconnect() {}
    virtual void onFrameDequeued(const uint64_t) {}
    virtual void onFrameCancelled(const uint64_t) {}
    virtual void onFrameDetached(const uint64_t) {}
    virtual void onFrameAvailable(const BufferItem& item) = 0;
    virtual void onFrameReplaced(const BufferItem&) {}
    virtual void onBuffersReleased() = 0;
    virtual void onSidebandStreamChanged() = 0;
    virtual void addAndGetFrameTimestamps(const NewFrameEventsEntry*,
                                          FrameEventHistoryDelta*) {}
    virtual void onSetFrameRate(float, int8_t, int8_t) {}
    virtual void onSlotCountChanged(int) {}
};

class IConsumerListener : public ConsumerListener, public IInterface {
public:
    DECLARE_META_INTERFACE(ConsumerListener)
};

class BnConsumerListener : public SafeBnInterface<IConsumerListener> {
public:
    BnConsumerListener() : SafeBnInterface<IConsumerListener>("BnConsumerListener") {}

    status_t onTransact(uint32_t code, const Parcel& data, Parcel* reply,
                        uint32_t flags = 0) override;
};

} // namespace android
