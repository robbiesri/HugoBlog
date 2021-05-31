---
title: "Graphics API Comparison - Part 1"
date: 2021-05-15T19:49:05-07:00
graphics-areas: ["API", "Vulkan", "D3D12"]
draft: true
---

## tl;dr

* Vulkan stinks

## Background

Graphics engineers have the hallowed pasttime of shitting on graphics APIs.
While it's cathartic to complain about how the latest API hoops reduce
quality of life, it's probably not useful for anybody to put it down in a blog.
What **would** be useful would be an attempt at delineaeting some of the
current gripes and deltas that I have with the modern _explicit_ rendering
APIs.

I'll constrain myself to D3D12, Vulkan, and Metal. I don't have a setup to test
Metal (no Apple laptop), so I might just make some doc related comments while I
wait for Mr. Cook to airmail me an M1.

D3D12 and Vulkan have a shared heritage from AMD's [Mantle][mantle-api]. It has
been interesting to formally (heh) examine the divergence in the APIs that were
spawned.

This will be a multi-part comparison. Here's a tentative roadmap of the API
comparison:

1. Bootstrapping - Initialization, device + queue creation, swapchain
1. Work coordination - Command buffer allocation, synchronization, submission
1. Shader compilation and program generation
1. Pipeline creation
1. Descriptor management
1. Resource management
1. Work generation
1. Ecosystem - Docs, samples, tooling

## Build Setup

### SDK Acquisition

Historically, if you wanted the latest D3D12 bits, you had to make sure your
Windows 10 SDK was in a good state (see [MS official docs][d3d12-setup]).
However, Microsoft announced something pretty cool in April 2021:
[the DX12 Agility SDK][d3d12-agility].

The [Vulkan SDK][vulkan-sdk] can be obtained from the LunarG website, as they
are the official purveyors of the Vulkan SDK.

### CMake Support

CMake includes official Vulkan support via [FindVulkan.cmake][FindVulkan] as of
3.7. There is no official support for D3D12, but DXC provides a sample
implementation for [FindD3D12.cmake][FindD3D12] that you can use in your own
projects.

### Scorecard

About the same. The Vulkan SDK was easier to obtain (and distribute, if your
work setup requires it). But now that DX12 is also obtainable standalone,
that levels the playing field.

## Device Enumeration

### D3D12

D3D12 uses the same DXGI infratructure as previous D3D releases. Step through a
list of adapters to see if it's suitable for your usage. The different DXGI
factories let you enumerate the adapters with different techniques.
`IDXGIFactory::EnumAdapters` is the most basic version. Recently, I've used
`IDXGIFactory6::EnumAdapterByGpuPreference` because it offers some convenience
for me when I'm working on my multi-GPU hybrid laptop, which is my primary
hobby workstation.

```cpp
uint32 adapterIndex = 0;
while (1) {
ComPtr<IDXGIAdapter1> adapter1;
HRESULT result = factory6->EnumAdapterByGpuPreference(
  adapterIndex, DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE,
  IID_PPV_ARGS(&adapter1));

if (DXGI_ERROR_NOT_FOUND == result) {
  break;
}

DXGI_ADAPTER_DESC1 desc;
adapter1->GetDesc1(&desc);

if (SUCCEEDED(D3D12CreateDevice(adapter1.Get(), D3D_FEATURE_LEVEL_11_0,
                                _uuidof(ID3D12Device), nullptr))) {
  // Save off info about adapter!
```

DXGI doesn't tell me how many adapters are on the system ahead of time, so if I
want to save off the results, I either need use `std::vector` (or some other
dynamically-sized data structure), or have a statically-sized array with a hard
cap on the number of adapters to query.

### Vulkan

Vulkan uses the pattern of "call an API once to determine list size, call API
again to populate newly allocated list". No different for device enumeration.
Vulkan requires a [VkInstance][vkinstance] to query  the list of
[VkPhysicalDevices][vkphysdev].

```cpp
VkInstance tempInstance;
VkInstanceCreateInfo instanceCreateInfo = {};
instanceCreateInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
vkCreateInstance(&instanceCreateInfo, NULL, &tempInstance);

uint32 physicalDeviceCount;
vkEnumeratePhysicalDevices(tempInstance, &physicalDeviceCount, NULL);

std::vector<VkPhysicalDevice> physicalDevices(physicalDeviceCount);
vkEnumeratePhysicalDevices(tempInstance, &physicalDeviceCount,
                           physicalDevices.data());
```

I _have_ seen laptops where the device ordering changes, which was  frustrating.
My current laptop (Asus G14) doesn't do that, but it also _only_ lists my
discrete NVIDIA GPU. I have previously seen my integrated AMD part show up. I
have had some recent Vulkan driver issues, so I'm wondering if something is
going on. Currently, D3D12 does list all GPUs present on my machine.

### Scorecard

I'd say this is a wash. If I'm being honest, it would be nice to have a hybrid
of the two approaches. It would be great to query the number of devices ahead of
time based on a filter argument, and get the resultant list of devices after
that with one call.

## Capablity Checks

The APIs approach the problem differently. For D3D12, you come in with known
quanitities for the capabilities of the implementation (with some broad
provisions). Vulkan supports a more diverse surface of devices. Therefore, the
API expects the developer to query the capabilities and adjust based on what
is actually available.

### D3D12

D3D12 is philosophically quite different compared to Vulkan. D3D12 provides
a known surface of capabilities containerized in
[D3D Feature Levels][d3d-feature-levels]. You are responsible for querying the
D3D12 runtime for devices that match your requested feature level.

```cpp
// from d3dcommon.h
enum D3D_FEATURE_LEVEL
    {
        D3D_FEATURE_LEVEL_1_0_CORE	= 0x1000,
        D3D_FEATURE_LEVEL_9_1	= 0x9100,
        D3D_FEATURE_LEVEL_9_2	= 0x9200,
        D3D_FEATURE_LEVEL_9_3	= 0x9300,
        D3D_FEATURE_LEVEL_10_0	= 0xa000,
        D3D_FEATURE_LEVEL_10_1	= 0xa100,
        D3D_FEATURE_LEVEL_11_0	= 0xb000,
        D3D_FEATURE_LEVEL_11_1	= 0xb100,
        D3D_FEATURE_LEVEL_12_0	= 0xc000,
        D3D_FEATURE_LEVEL_12_1	= 0xc100
    } 	D3D_FEATURE_LEVEL;
```

Even though the DXGI/D3D12 interface is _generally_ simpler, there are a couple
gotchas:

* Developer has to know about the various Factory and Adapter versions.
* `IDXGIFactory5::CheckFeatureSupport` does exist, which allows for feature
  queries

### Vulkan

Vulkan splits the capabilities across the Instance and PhysicalDevice/Device.
[VkInstance][vkinstance] contains information about the application and the
local Vulkan installation, which could include the loader, SDK, runtime and
layers. [VkPhysicalDevice][vkphysdev] contains the implementation information
(aka the device and driver). But you cannot query the VkPhysicalDevice
information without creating (and deleting) an instance, which is slightly
annoying.

Once you have an instance, you can query the device properties, layers, and
extensions. A Vulkan core concept (like OpenGL) is extensions. Devices will
support a wide variety of extensions, and those extensions have a wide variety
of capabilities to check.

```cpp
vkCreateInstance(&instanceCreateInfo, NULL, &tempInstance);

// query layers
// query instance extensions

uint32 physicalDeviceCount;
vkEnumeratePhysicalDevices(tempInstance, &physicalDeviceCount, NULL);

std::vector<VkPhysicalDevice> physicalDevices(physicalDeviceCount);
vkEnumeratePhysicalDevices(tempInstance, &physicalDeviceCount,
                            physicalDevices.data());

for (VkPhysicalDevice physicalDevice : physicalDevices) {
VkPhysicalDeviceProperties2 props2;
props2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
props2.pNext = NULL;
vkGetPhysicalDeviceProperties2(physicalDevice, &props2);

// query device extensions
}
```

### Scorecard

This is tough. My initial impression is that I prefer the D3D12 model, where I
can go in and _know_ what I'm getting ahead of time. Is there value to the
flexibility of the Vulkan model? Of course. It's great for experimentation of
new features. But it is not fun or easy to manage the myriad of combinations
across implementations.

It also bothers me that I have to create a VkInstance, just to manually tear it
down (D3D12 tears down the test adapter implicitly because we have to use a
ComPtr).

## Device and Queue Creation

### D3D12

Creating the device is easy enough. After the application has enumerated the
adapters, and decided which one it wants to create, the app can use the same
infrastructure to actually create the device.

```cpp

ComPtr<IDXGIAdapter1> adapter1;
HRESULT result = m_dxgiFactory6->EnumAdapterByGpuPreference(
  requestedAdapterIndex, DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE,
  IID_PPV_ARGS(&adapter1));

if (DXGI_ERROR_NOT_FOUND == result) {
  spdlog::error("DXGIAdapter not found, adapterIndex: {}",
            requestedAdapterIndex);
  return;
}

DXGI_ADAPTER_DESC1 desc;
adapter1->GetDesc1(&desc);

result = D3D12CreateDevice(adapter1.Get(), D3D_FEATURE_LEVEL_11_0,
                            IID_PPV_ARGS(&m_device));
```

D3D12 does not mandate queue specification during device creation time. Whatever
the application wants, they can request from the API. However, the application
is responsible for validating that their request was successful.

```cpp
std::vector<ComPtr<ID3D12CommandQueue>> commandQueues(queueRequestCount);
for (auto requestedQueue : commandQueues) {
  D3D12_COMMAND_QUEUE_DESC queueDesc = {};
  queueDesc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
  queueDesc.Type = GenerateCommandListType(/*app type*/);
  HRESULT result = m_device->CreateCommandQueue(
    &queueDesc, IID_PPV_ARGS(&m_commandQueues[queueInsertIndex]));

  // Validate result
}
```

### Vulkan

Vulkan requires that we specify the requested queues during device creation.
Which means we have to query that information from VkPhysicalDevice.

```cpp
void GetQueueFamilyInfo(
    VkPhysicalDevice physicalDevice,
    std::vector<VkQueueFamilyProperties2> &queueFamilyInfos) {
  uint32 queueFamilyCount = 0;
  vkGetPhysicalDeviceQueueFamilyProperties2(physicalDevice, &queueFamilyCount,
                                            NULL);

  queueFamilyInfos.resize(queueFamilyCount);

  for (auto &qfi : queueFamilyInfos) {
    qfi.sType = VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2;
  }

  vkGetPhysicalDeviceQueueFamilyProperties2(physicalDevice, &queueFamilyCount,
                                            queueFamilyInfos.data());
}
```

Once we have the queue family information, we can use it to populate our queue
requests. We have to generate a list of `VkDeviceQueueCreateInfo`.

```cpp
std::vector<VkDeviceQueueCreateInfo> deviceQueueCreateInfos;
std::vector<std::vector<float>> queuePriorities;

for (const auto &queueRequest : queueRequestList) {
  VkDeviceQueueCreateInfo deviceQueueRequest = {};
  deviceQueueRequest.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  deviceQueueRequest.queueCount = queueRequest.count;

  queuePriorities.emplace_back(queueRequest.count, 1.0f);
  deviceQueueRequest.pQueuePriorities = queuePriorities.back().data();

  deviceQueueRequest.queueFamilyIndex = queueRequest.qfIndex;

  deviceQueueCreateInfos.push_back(deviceQueueRequest);
}
```

Now that we finally have our queue requests, we can plug that into our device
request. There's a couple other important aspects to device creation, which
include layers, extensions and features (which I won't cover).

```cpp
VkPhysicalDeviceFeatures2 features2 = {};
features2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
vkGetPhysicalDeviceFeatures2(physicalDevice, &features2);

VkDeviceCreateInfo deviceCreateInfo = {};
deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
deviceCreateInfo.pEnabledFeatures = &features2.features;

deviceCreateInfo.pQueueCreateInfos = deviceQueueCreateInfos.data();
deviceCreateInfo.queueCreateInfoCount =
    static_cast<uint32>(deviceQueueCreateInfos.size());

// Fill these in if you want layers and extensions
deviceCreateInfo.enabledLayerCount = 0;
deviceCreateInfo.enabledExtensionCount = 0;

VkResult result =
  vkCreateDevice(physicalDevice, &deviceCreateInfo, NULL, &device);
```

And now that we've finally created the device, we can fetch our queues!

```cpp
std::vector<VkQueue> fetchedQueues;
for (const auto &queueRequest : queueRequestList) {

  for (uint32 queueIndex = 0; queueIndex < queueRequest.count; queueIndex++) {
    VkQueue queue;
    m_deviceAPITable.vkGetDeviceQueue(device, queueRequest.qfIndex, queueIndex,
                                      &queue);
    fetchedQueues.push_back(queue);
  }
}
```

### Scorecard

I _greatly_ prefer the D3D12 model, though it is annoying that I don't "know"
the number of queues that are available upfront. I'd expect most "professional"
applications are coming in with an expectation of queues available on devices. I
was surprised I couldn't _find_ some expected defaults in the D3D12 SDK docs.
I know IHVs were actively evolving their capabilities, but maybe they could have
had feature levels for the queues as well.

Vulkan is frustrating because of how _enormous_ the input structure is. It's
easy to make a mistake in your device creation request, and validation isn't
guaranteed to catch something that you didn't intend. It's also annoying that
you have to specify the queues up front, only to request them later on. Why not
just use the D3D12 model in that case? Why not just "enable" all queues by
default? Why do I need to know the specific index in the queue family? When do
I ever need to know that information after fetching the queue?

## Window + Swapchain

At the time of writing, I'm working with the Windows API for window creation and
management, because I'm on a Windows machine. I'll come back once I have more
multi-platform information.

### D3D12

It is unfair to compare Vulkan, with no tie-in platform, against D3D12 working
on Windows. Still, I think there are interesting comparables in the API design.

Armed with the window handle, it's quite easy to create a swapchain. The only
unique requirement is passing in a ID3D12CommandQueue. The requirement is barely
documented. The D3D12 samples say "Swap chain needs the queue so that it can
force a flush on it". I don't know what that means. 

Lukcily, because Vulkan is more explicit, we can reasonably infer that this must
be the queue that is used in order to _present_ the swapchain (along with other
work). I suppose this means that we cannot _change_ queues that we present on
without re-creating the swapchain. While doing some research, I stumbled upon
[IDXGISwapChain3::ResizeBuffers1](dxgi-resize). There is some documentation here
about multiple queues, but I don't plan on using this yet.

```cpp
    DXGI_SWAP_CHAIN_DESC1 swapChainDesc = {};
    swapChainDesc.BufferCount = m_swapchainBufferCount;
    swapChainDesc.Width = windowWidth;
    swapChainDesc.Height = windowHeight;
    swapChainDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    swapChainDesc.SampleDesc.Count = 1;

    ComPtr<ID3D12CommandQueue> gfxCommandQueue =
        getCommandQueue(QueueType::kGraphics);
    ComPtr<IDXGISwapChain1> swapChain;
    HRESULT result = m_dxgiFactory6->CreateSwapChainForHwnd(
        gfxCommandQueue.Get(),
        hWnd, &swapChainDesc, nullptr, nullptr, &swapChain);

    ComPtr<IDXGISwapChain3> m_swapchain1;
    result = swapChain.As(&m_swapchain1);
```

Because this will come up with Vulkan, let's also look at window size and
format. We've either created our window, or we're on console, where we know the
predetermined output sizes. In either case, we should know our window size.
D3D12 also allows us to pass 0 for both `Width` and `Height`, which means we ask
the runtime to give us the same size as our window.

Format support is a bit different. We need to use
`ID3D12Device::CheckFeatureSupport`. Our fetched information is placed into
`D3D12_FEATURE_DATA_FORMAT_SUPPORT`, where we need to check for the
`D3D12_FORMAT_SUPPORT1_DISPLAY` bit. This tells us we can present with this
format.

```cpp
D3D12_FEATURE_DATA_FORMAT_SUPPORT formatSupport = {};
formatSupport.format = DXGI_FORMAT_R8G8B8A8_UNORM;
m_device->CheckFeatureSupport(D3D12_FEATURE_FORMAT_SUPPORT,
        &formatSupport, sizeof(D3D12_FEATURE_DATA_FORMAT_SUPPORT));
bool formatSupportsDisplay = (formatSupport.Support1 & D3D12_FORMAT_SUPPORT1_DISPLAY) != 0;
```

Once we have the swapchain, we can fetch the rendertargets from the swapchain,
and bind those to descriptors.

```cpp
    D3D12_CPU_DESCRIPTOR_HANDLE rtvHandle(
        m_swapchainRtvHeap->GetCPUDescriptorHandleForHeapStart());

    for (uint32 swapchainRtvIndex = 0;
         swapchainRtvIndex < m_swapchainBufferCount; swapchainRtvIndex++) {
      HRESULT result = m_swapchain1->GetBuffer(
          swapchainRtvIndex,
          IID_PPV_ARGS(&m_swapchainRenderTargets[swapchainRtvIndex]));
      RSBL_ASSERT(SUCCEEDED(result));

      m_device->CreateRenderTargetView(
          m_swapchainRenderTargets[swapchainRtvIndex].Get(), nullptr,
          rtvHandle);

      rtvHandle.ptr = SIZE_T(INT64(rtvHandle.ptr) + INT64(m_rtvDescriptorSize));
    }
```

The swapchains start out in the `D3D12_RESOURCE_STATE_COMMON` state, which is
synonymous with `D3D12_RESOURCE_STATE_PRESENT`. While we might not present the
frame immediately, it is convenient to have the swapchains in the PRESENT state
to start. Typically, frame logic expects that the swapchains last operation was
a present, so we don't have to special case our first frame.

### Vulkan

On Vulkan, we have to go back to device creation time to make sure we're setup
correctly. Swapchains are not enabled by default. In order to do so, we have
to enable extensions in both instance and device creation.

```cpp
      std::unordered_map<std::string, VkExtensionProperties>
          extensionProperties = GetInstanceExtensionProperties();
      bool khrSurfaceAvailable =
          (extensionProperties.find(VK_KHR_SURFACE_EXTENSION_NAME) !=
           extensionProperties.end());
      bool platformSurfaceAvailable =
          (extensionProperties.find(VK_KHR_WIN32_SURFACE_EXTENSION_NAME) !=
           extensionProperties.end());
      bool khrGetSurfaceCapabilities2Available =
          (extensionProperties.find(VK_KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME) !=
           extensionProperties.end());

    std::vector<const char *> requestedExtensionNames;
      requestedExtensionNames.push_back(VK_KHR_SURFACE_EXTENSION_NAME);
      requestedExtensionNames.push_back(VK_KHR_WIN32_SURFACE_EXTENSION_NAME);
      requestedExtensionNames.push_back(VK_KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME);

      VkInstanceCreateInfo instanceCreateInfo = {};
      instanceCreateInfo.enabledExtensionCount =
          static_cast<uint32>(requestedExtensionNames.size());
      instanceCreateInfo.ppEnabledExtensionNames =
          requestedExtensionNames.data();


      std::unordered_map<std::string, VkExtensionProperties>
        deviceExtensionProperties =
            GetDeviceExtensionProperties(physicalDevice);

      bool swapchainExtAvailable =
          deviceExtensionProperties.find(VK_KHR_SWAPCHAIN_EXTENSION_NAME) !=
          deviceExtensionProperties.end();
      bool swapchainMutableFormatExtAvailable =
          deviceExtensionProperties.find(
              VK_KHR_SWAPCHAIN_MUTABLE_FORMAT_EXTENSION_NAME) !=
          deviceExtensionProperties.end();
      bool imageFormatListExtAvailable =
          deviceExtensionProperties.find(VK_KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME) !=
          deviceExtensionProperties.end();

  std::vector<const char *> requestedExtensionNames;

      if (swapchainExtAvailable) {
        requestedExtensionNames.push_back(VK_KHR_SWAPCHAIN_EXTENSION_NAME);
        swapchainEnabled = true;
      }
      if (swapchainMutableFormatExtAvailable && imageFormatListExtAvailable) {
        requestedExtensionNames.push_back(
            VK_KHR_SWAPCHAIN_MUTABLE_FORMAT_EXTENSION_NAME);
        requestedExtensionNames.push_back(
            VK_KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME);
        swapchainMutableFormatEnabled = true;
      }

  VkDeviceCreateInfo deviceCreateInfo = {};
    deviceCreateInfo.enabledExtensionCount =
        static_cast<uint32>(requestedExtensionNames.size());
    deviceCreateInfo.ppEnabledExtensionNames = requestedExtensionNames.data();
```

This just what it takes to _enable_ the ability to create a swapchain. Jesus.
Technically, we don't need `VK_KHR_SWAPCHAIN_MUTABLE_FORMAT` or
`VK_KHR_IMAGE_FORMAT_LIST`, but it makes it easier to manage the swapchain
formats.

Before we actually create the swapchain, we need to create a `VkSurfaceKHR`.
Vulkan cannot _natively_ understand Windows handles, which is reasonable. We
have to marshall them through a platform extension that creates a
platform-independent `VkSurfaceKHR` that we can use to create a swapchain. We
can also use the surface to query information about what display modes the
implementation supports. This includes size and format.

```cpp
    VkWin32SurfaceCreateInfoKHR surfaceCreateInfo = {};
    surfaceCreateInfo.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
    surfaceCreateInfo.hinstance = reinterpret_cast<HINSTANCE>(appHandle);
    surfaceCreateInfo.hwnd = reinterpret_cast<HWND>(windowHandle);

    VkResult result =
        vkCreateWin32SurfaceKHR(instance, &surfaceCreateInfo, NULL, &m_surface);

  VkSurfaceCapabilities2KHR surfaceCaps = {};
    surfaceCaps.sType = VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_2_KHR; // driver bug

    VkPhysicalDeviceSurfaceInfo2KHR surfaceInfo = {};
    surfaceInfo.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SURFACE_INFO_2_KHR;
    surfaceInfo.surface = m_surface;
    VkResult result = vkGetPhysicalDeviceSurfaceCapabilities2KHR(
        m_physicalDevice, &surfaceInfo, &surfaceCaps);

  std::vector<VkSurfaceFormat2KHR> surfaceFormats;
    surfaceCaps.sType = VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_2_KHR;

    VkPhysicalDeviceSurfaceInfo2KHR surfaceInfo = {};
    surfaceInfo.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SURFACE_INFO_2_KHR;
    surfaceInfo.surface = m_surface;
    VkResult result = vkGetPhysicalDeviceSurfaceCapabilities2KHR(
        m_physicalDevice, &surfaceInfo, &surfaceCaps);

    uint32 surfaceFormatCount = 0;
    result = vkGetPhysicalDeviceSurfaceFormats2KHR(
        m_physicalDevice, &surfaceInfo, &surfaceFormatCount, NULL);

    if (surfaceFormatCount > 0) {
      surfaceFormats.resize(surfaceFormatCount,
                            {VK_STRUCTURE_TYPE_SURFACE_FORMAT_2_KHR});
      result = vkGetPhysicalDeviceSurfaceFormats2KHR(
          m_physicalDevice, &surfaceInfo, &surfaceFormatCount,
          surfaceFormats.data());
    }
```

Just like D3D12, we need to consider the queue when we think about how we'll
submit the present. We don't have to pass in an actual queue to the
implementation. Instead, we tell the implementation with _queue families_ we'd
like to use. More flexibility than D3D12, at the cost of some indirection.

```cpp
      VkBool32 presentSupported = VK_TRUE;
      uint32 queueFamilyIndex = 0;
      VkResult result = vkGetPhysicalDeviceSurfaceSupportKHR(
          m_physicalDevice, queueFamilyIndex, m_surface, &presentSupported);
```

Now we know enough to actually create the swapchain!

There's a bit more information here than what we have with D3D12. One of the
more annoying things is that all present modes are not guaranteed to be
available with Vulkan. Which means we have to query it. DXGI/D3D12 offer
guaranteed flip modes, so we can just choose without having to check.

```cpp
    VkSwapchainCreateInfoKHR swapchainCreateInfo = {};
    swapchainCreateInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    swapchainCreateInfo.flags = 0;
    swapchainCreateInfo.surface = m_surface;
    uint32 imageCount = std::max(
        m_swapchainBufferCount, surfaceCaps.surfaceCapabilities.minImageCount);
    imageCount =
        std::min(imageCount, surfaceCaps.surfaceCapabilities.maxImageCount);
    swapchainCreateInfo.minImageCount = imageCount;

    // defaults that every implementation should support
    VkFormat swapchainFormat = VK_FORMAT_B8G8R8A8_UNORM;
    VkColorSpaceKHR swapchainColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
    swapchainCreateInfo.imageFormat = swapchainFormat;
    swapchainCreateInfo.imageColorSpace = swapchainColorSpace;

    swapchainCreateInfo.imageExtent = {windowWidth, windowHeight};
    swapchainCreateInfo.imageArrayLayers = 1;

    // Check if platform supports VK_IMAGE_USAGE_STORAGE_BIT
    VkImageUsageFlags swapchainImageUsageFlags =
        surfaceCaps.surfaceCapabilities.supportedUsageFlags;
    swapchainCreateInfo.imageUsage = swapchainImageUsageFlags;
    swapchainCreateInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;

    uint32 queueFamilyIndex = 0;
    swapchainCreateInfo.queueFamilyIndexCount = 1;
    swapchainCreateInfo.pQueueFamilyIndices = &queueFamilyIndex;

    swapchainCreateInfo.preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
    swapchainCreateInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

    VkPresentModeKHR swapchainPresentMode = VK_PRESENT_MODE_FIFO_KHR;
    if (presentModes.size() > 0) {
      for (VkPresentModeKHR presentMode : presentModes) {
        if (VK_PRESENT_MODE_MAILBOX_KHR == presentMode) {
          swapchainPresentMode = VK_PRESENT_MODE_MAILBOX_KHR;
          break;
        }
      }
    }
    swapchainCreateInfo.presentMode = swapchainPresentMode;

    swapchainCreateInfo.clipped = VK_FALSE;
    swapchainCreateInfo.oldSwapchain = VK_NULL_HANDLE;

    vkCreateSwapchainKHR(
        m_device, &swapchainCreateInfo, NULL, &m_swapchain);
```

Last thing to do are to grab the images from the swapchain! But there's a twist,
at least compared to D3D12. In D3D12, the swapchain resources are ready for
display immediately, which is nice for our rendering pipeline. In Vulkan, that
is not the case. In order to simplify our render loop logic, we'll want to
put the Vulkan swapchain images into `VK_IMAGE_LAYOUT_PRESENT_SRC_KHR` layout.
In order to do that, we actually need to _submit a command buffer_ to perform
the layout transition! WHY? The DXGI swapchains already have access to a
D3D12 queue, so I assume the runtime does the transition behind the scenes. Why,
Vulkan, WHY?!

Something else that is frustrating is that Vulkan might actually return more
images in the swapchain than I had requested. I suppose that isn't a big deal,
since I'm not obliged to use all images during present. I just don't understand
why it has to do that.

We won't cover all the process for grabbing queues, command buffer generation,
and submission. That's a future post. But I still have to do it, bleh.

```cpp

    uint32 swapchainImageCount;
    VkResult result = vkGetSwapchainImagesKHR(
        m_device, m_swapchain, &swapchainImageCount, NULL);

    m_swapchainBufferCount = swapchainImageCount;
    m_swapchainImages.resize(m_swapchainBufferCount);

    result = vkGetSwapchainImagesKHR(m_device, m_swapchain,
                                                      &m_swapchainBufferCount,
                                                      m_swapchainImages.data());

    VkCommandPoolCreateInfo tempCommandPoolCreateInfo = {};
    tempCommandPoolCreateInfo.sType =
        VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    tempCommandPoolCreateInfo.flags = VK_COMMAND_POOL_CREATE_TRANSIENT_BIT; 
    tempCommandPoolCreateInfo.queueFamilyIndex =
        m_queueTypeToQueueFamilyIndex[QueueType::kGraphics];
    VkCommandPool tempCommandPool;
    VkResult result = vkCreateCommandPool(
        m_device, &tempCommandPoolCreateInfo, NULL, &tempCommandPool);

    VkCommandBufferAllocateInfo tempCommandBufferAllocInfo = {};
    tempCommandBufferAllocInfo.sType =
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    tempCommandBufferAllocInfo.commandPool = tempCommandPool;
    tempCommandBufferAllocInfo.level =
        VkCommandBufferLevel::VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    tempCommandBufferAllocInfo.commandBufferCount = 1;
    VkCommandBuffer tempCommandBuffer;
    result = vkAllocateCommandBuffers(
        m_device, &tempCommandBufferAllocInfo, &tempCommandBuffer);

    VkCommandBufferBeginInfo tempCommandBufferBeginInfo = {};
    tempCommandBufferBeginInfo.sType =
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    tempCommandBufferBeginInfo.flags =
        VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    result = vkBeginCommandBuffer(tempCommandBuffer,
                                                   &tempCommandBufferBeginInfo);

    std::vector<VkImageMemoryBarrier> barriers(m_swapchainBufferCount);
    for (uint32 swapchainImageIndex = 0;
         swapchainImageIndex < m_swapchainBufferCount; swapchainImageIndex++) {
      VkImageMemoryBarrier &barrier = barriers[swapchainImageIndex];

      barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
      barrier.srcAccessMask = 0;
      barrier.dstAccessMask = 0; // should this be something like memory_read?
      barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
      barrier.newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
      barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
      barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
      barrier.image = m_swapchainImages[swapchainImageIndex];

      barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
      barrier.subresourceRange.baseMipLevel = 0;
      barrier.subresourceRange.levelCount = 1;
      barrier.subresourceRange.baseArrayLayer = 0;
      barrier.subresourceRange.layerCount = 1;
    }

    vkCmdPipelineBarrier(
        tempCommandBuffer, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, 0, 0, NULL, 0, NULL,
        m_swapchainBufferCount, barriers.data());

    vkEndCommandBuffer(tempCommandBuffer);

    VkSubmitInfo submitInfo = {};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    VkPipelineStageFlags waitFlags = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;
    submitInfo.pWaitDstStageMask = &waitFlags;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &tempCommandBuffer;

    VkQueue graphicsQueue = getQueue(QueueType::kGraphics);
    result = vkQueueSubmit(graphicsQueue, 1, &submitInfo,
                                            VK_NULL_HANDLE);

    vkQueueWaitIdle(graphicsQueue);

    vkFreeCommandBuffers(m_device, tempCommandPool, 1,
                                          &tempCommandBuffer);
    vkDestroyCommandPool(m_device, tempCommandPool, nullptr);

```

### Scorecard

This is a clear win for D3D12. It's not even close.

I don't really understand why Vulkan makes me do so much more work for the same
functionality. Swapchains should have been a first class citizen, with a cap bit
in the physical device capabilities/features. Swapchains should just be created
in PRESENT layout. D3D12 understands that these are nearly universal workflows,
and just does them.

[amd-mantle]: https://en.wikipedia.org/wiki/Mantle_(API)

[FindD3D12]: https://github.com/Microsoft/DirectXShaderCompiler/blob/master/cmake/modules/FindD3D12.cmake
[FindVulkan]: https://github.com/Kitware/CMake/blob/master/Modules/FindVulkan.cmake

[d3d12-setup]: https://docs.microsoft.com/en-us/windows/win32/direct3d12/directx-12-programming-environment-set-up
[d3d12-agility]: https://devblogs.microsoft.com/directx/announcing-dx12agility/

[d3d-feature-levels]: https://docs.microsoft.com/en-us/windows/win32/direct3d11/overviews-direct3d-11-devices-downlevel-intro
[dxgi-resize]: https://docs.microsoft.com/en-us/windows/win32/api/dxgi1_4/nf-dxgi1_4-idxgiswapchain3-resizebuffers1

[vulkan-sdk]: https://vulkan.lunarg.com/sdk/home
[vkinstance]: https://www.khronos.org/registry/vulkan/specs/1.2-extensions/man/html/VkInstance.html
[vkphysdev]: https://www.khronos.org/registry/vulkan/specs/1.2-extensions/man/html/VkPhysicalDevice.html
[vkdev]: https://www.khronos.org/registry/vulkan/specs/1.2-extensions/man/html/VkDevice.html
