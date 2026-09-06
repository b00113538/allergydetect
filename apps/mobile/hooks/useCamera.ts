import { useCameraPermissions } from "expo-camera";
import * as ImagePicker from "expo-image-picker";

export function useCamera() {
  const [permission, requestPermission] = useCameraPermissions();

  const pickFromGallery = async (): Promise<string | null> => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 0.8,
    });
    if (result.canceled) return null;
    return result.assets[0]?.uri ?? null;
  };

  return {
    permission,
    requestPermission,
    granted: permission?.granted ?? false,
    pickFromGallery,
  };
}
