/**
 * Performs a shallow merge of JSON fields.
 *
 * - If newData is undefined, returns undefined (no change).
 * - If newData is explicitly null, returns null (clears the field).
 * - If both are objects, strips undefined values from newData and merges it over oldData.
 * - Otherwise, replaces oldData with newData.
 *
 * @param oldData The existing JSON object from the database
 * @param newData The incoming DTO JSON object
 * @returns The merged result
 */
export const mergeJson = (oldData: any, newData: any): any => {
  if (newData === undefined) return undefined;
  if (newData === null) return null;

  /* eslint-disable @typescript-eslint/no-unsafe-assignment */
  const cleanNewData =
    typeof newData === 'object' && newData !== null && !Array.isArray(newData)
      ? Object.fromEntries(
          /* eslint-disable @typescript-eslint/no-unsafe-argument */
          Object.entries(newData).filter(([, v]) => v !== undefined),
        )
      : newData;

  if (
    typeof oldData === 'object' &&
    oldData !== null &&
    !Array.isArray(oldData) &&
    typeof cleanNewData === 'object' &&
    !Array.isArray(cleanNewData)
  ) {
    return { ...oldData, ...cleanNewData };
  }

  return cleanNewData;
};
