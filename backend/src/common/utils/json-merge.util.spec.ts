import { mergeJson } from './json-merge.util';

describe('mergeJson', () => {
  it('should return undefined if newData is undefined', () => {
    expect(mergeJson({ bio: 'hello' }, undefined)).toBeUndefined();
  });

  it('should return null if newData is explicitly null', () => {
    expect(mergeJson({ bio: 'hello' }, null)).toBeNull();
  });

  it('should preserve old data if newData is an empty object', () => {
    const oldData = { bio: 'hello', theme: 'dark' };
    expect(mergeJson(oldData, {})).toEqual(oldData);
  });

  it('should shallow merge objects', () => {
    const oldData = { bio: 'hello', theme: 'dark' };
    const newData = { theme: 'light', discord: 'user#1234' };

    expect(mergeJson(oldData, newData)).toEqual({
      bio: 'hello',
      theme: 'light',
      discord: 'user#1234',
    });
  });

  it('should ignore undefined keys in newData during merge', () => {
    const oldData = { theme: 'dark', autoAccept: true };
    const newData = { theme: 'light', autoAccept: undefined };

    expect(mergeJson(oldData, newData)).toEqual({
      theme: 'light',
      autoAccept: true,
    });
  });

  it('should clear fields if explicitly set to null in newData', () => {
    const oldData = { theme: 'dark', discord: 'user#1234' };
    const newData = { discord: null };

    expect(mergeJson(oldData, newData)).toEqual({
      theme: 'dark',
      discord: null,
    });
  });

  it('should replace arrays entirely', () => {
    const oldData = { genres: ['POP', 'ROCK'] };
    const newData = { genres: ['JAZZ'] };

    expect(mergeJson(oldData, newData)).toEqual({ genres: ['JAZZ'] });
  });

  it('should replace oldData if oldData is not an object', () => {
    expect(mergeJson('string_data', { key: 'value' })).toEqual({
      key: 'value',
    });
    expect(mergeJson(null, { key: 'value' })).toEqual({ key: 'value' });
  });

  it('should replace oldData if newData is not an object', () => {
    expect(mergeJson({ key: 'value' }, 'string_data')).toEqual('string_data');
    expect(mergeJson({ key: 'value' }, ['array', 'data'])).toEqual([
      'array',
      'data',
    ]);
  });
});
