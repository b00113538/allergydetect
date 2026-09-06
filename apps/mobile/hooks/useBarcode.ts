import { useState } from "react";

import { api } from "@/lib/api";
import type { BarcodeProduct } from "@/types";

export function useBarcode() {
  const [loading, setLoading] = useState(false);
  const [product, setProduct] = useState<BarcodeProduct | null>(null);
  const [scanned, setScanned] = useState(false);

  const lookup = async (barcode: string) => {
    setScanned(true);
    setLoading(true);
    try {
      const result = await api.scanBarcode(barcode);
      setProduct(result);
      return result;
    } finally {
      setLoading(false);
    }
  };

  const reset = () => {
    setScanned(false);
    setProduct(null);
  };

  return { loading, product, scanned, lookup, reset };
}
