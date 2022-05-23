#ifndef FLUTTER_PLUGIN_NSD_WINDOWS_V2_PLUGIN_H_
#define FLUTTER_PLUGIN_NSD_WINDOWS_V2_PLUGIN_H_

#include "nsd_windows.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace nsd_windows_v2 {

	class NsdWindowsV2Plugin : public flutter::Plugin {
	public:
		static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

		NsdWindowsV2Plugin(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel);
		virtual ~NsdWindowsV2Plugin();

		// Disallow copy and assign.
		NsdWindowsV2Plugin(const NsdWindowsV2Plugin&) = delete;
		NsdWindowsV2Plugin& operator=(const NsdWindowsV2Plugin&) = delete;

	private:

		nsd_windows::NsdWindows nsdWindows;
	};

}  // namespace nsd_windows_v2

#endif  // FLUTTER_PLUGIN_NSD_WINDOWS_V2_PLUGIN_H_
