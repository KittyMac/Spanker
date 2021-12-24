// TBJSONReader.cs
//
// TBJSONReader is a C# adaptation of the fabulously performant TBXML ( https://github.com/71squared/TBXML )
//
// The MIT License (MIT)
// 
// Copyright (c) 2016 Rocco Bowling
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


using System;
using System.Text;
using System.Collections.Generic;
#if ENABLE_IL2CPP
using Unity.IL2CPP.CompilerServices;
#endif

namespace TB
{
	public enum ValueType {
		Unknown,
		Null,
		String,
		Int,
		Double,
		Element
	}

	public enum ElementType {
		Object,
		Array
	}

	public struct TBJSONValue {
		public ValueType type;
		public long nameIdx;
		public long valueIdx;
		public TBJSONElement element;

		public void Clear() {
			type = ValueType.Unknown;
			nameIdx = 0;
			valueIdx = 0;
			element = null;
		}
	}

	public class TBJSONElement {
		public TBJSONReader tbxml;
		public ElementType type;
		public List<TBJSONValue> values = new List<TBJSONValue> ();

		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		public string GetName(int i) {
			if (i < values.Count) {
				TBJSONValue attribute = values [i];
				if (attribute.nameIdx == 0) {
					return null;
				}
				return System.Text.UTF8Encoding.Default.GetString (tbxml.bytes, (int)attribute.nameIdx, (int)tbxml.strlen (attribute.nameIdx));
			}
			return null;
		}

		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		public TBJSONElement GetElement(int i) {
			if (i < values.Count) {
				return values [i].element;
			}
			return null;
		}

		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		public string GetValue(int i) {
			if (i < values.Count) {
				TBJSONValue attribute = values [i];
				if (attribute.valueIdx == 0) {
					return null;
				}
				return System.Text.UTF8Encoding.Default.GetString (tbxml.bytes, (int)attribute.valueIdx, (int)tbxml.strlen (attribute.valueIdx));
			}
			return null;
		}

		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		public ValueType GetType(int i) {
			if (i < values.Count) {
				return values [i].type;
			}
			return ValueType.Unknown;
		}


	}

	public class TBJSONReader {
		public byte[] bytes;
		public long bytesLength;

		public TBJSONReader(byte[] bytes, Action<TBJSONElement,TBJSONElement,int> onStartElement, Action<TBJSONElement,TBJSONElement,int> onEndElement, bool useDuplicateBytes = false) {

			// set up the bytes array
			if (useDuplicateBytes) {
				this.bytes = (byte[])bytes.Clone ();
			} else {
				this.bytes = bytes;
			}

			bytesLength = bytes.Length;

			DecodeBytes(onStartElement, onEndElement);
		}
			
		public TBJSONReader(string xmlString, Action<TBJSONElement,TBJSONElement,int> onStartElement, Action<TBJSONElement,TBJSONElement,int> onEndElement) : this(Encoding.UTF8.GetBytes (xmlString), onStartElement, onEndElement, false) {

		}

		#region DECODE XML


		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		private long strstrNoEscaped(long idx, byte b0){
			// look forward for the matching character, not counting escaped versions of it
			long bytesLengthMinusSearchSize = bytesLength;
			byte[] localBytes = bytes;

			while (idx < bytesLengthMinusSearchSize) {
				if (localBytes [idx] == 0)
					break;

				if (localBytes [idx] == b0 && localBytes [idx-1] != (byte)'\\') {
					return idx;
				}
				idx++;
			}
			return bytesLength;
		}

		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		private long strskip(long idx,params byte[] byteList){
			long bytesLengthMinusSearchSize = bytesLength;
			byte[] localBytes = bytes;
			byte compareByte;

			while (idx < bytesLengthMinusSearchSize) {
				compareByte = localBytes [idx];
				if (compareByte == 0)
					break;

				bool shouldSkip = false;
				for (int i = 0; i < byteList.Length; i++) {
					if (compareByte == byteList [i]) {
						shouldSkip = true;
					}
				}
				if (shouldSkip == false) {
					return idx;
				}
				idx++;
			}
			return bytesLength;
		}

		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		private long strstr1(long idx, params byte[] byteList){
			long bytesLengthMinusSearchSize = bytesLength;
			byte[] localBytes = bytes;
			byte compareByte;

			while (idx < bytesLengthMinusSearchSize) {
				compareByte = localBytes [idx];
				if (compareByte == 0)
					break;

				for (int i = 0; i < byteList.Length; i++) {
					if (compareByte == byteList [i]) {
						return idx;
					}
				}
				idx++;
			}
			return bytesLength;
		}

		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		public long strncmp(long idx, byte[] b, long n){
			// From stncmp() man page:
			// The strcmp() and strncmp() functions return an integer greater than, equal to, or less than 0, according as the string s1 is
			// greater than, equal to, or less than the string s2.  The comparison is done using unsigned characters, so that `\200' is greater than `\0'.
			long i = 0;
			byte[] localBytes = bytes;

			while (i < n && idx < bytesLength && localBytes [idx] == b [i] && localBytes [idx] != 0) {
				i++;
				idx++;
			}

			if (i != b.Length) {
				// failed to match
				return -1;
			}

			return 0;
		}

		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		public long strlen(long idx){
			// From strlen man page:
			// The strlen() function returns the number of characters that precede the terminating NUL character.  The strnlen() function
			// returns either the same result as strlen() or maxlen, whichever is smaller.
			long startIdx = idx;
			byte[] localBytes = bytes;
			while (idx < bytesLength && localBytes [idx] != 0) {
				idx++;
			}
			return idx - startIdx;
		}

		#if ENABLE_IL2CPP
		[Il2CppSetOption(Option.NullChecks, false)]
		[Il2CppSetOption(Option.ArrayBoundsChecks, false)]
		[Il2CppSetOption(Option.DivideByZeroChecks, false)]
		#endif
		private void DecodeBytes(Action<TBJSONElement,TBJSONElement,int> onStartElement, Action<TBJSONElement,TBJSONElement,int> onEndElement) {

			byte[] localBytes = bytes;
			long localBytesLength = bytesLength;

			Stack<TBJSONElement> elementStack = new Stack<TBJSONElement> ();
			Stack<TBJSONElement> freeElementList = new Stack<TBJSONElement> ();

			TBJSONValue xmlAttribute = new TBJSONValue ();

			// set elementStart pointer to the start of our xml
			long currentIdx = 0;

			TBJSONElement xmlElement = null;

			// find next element start
			while ((currentIdx = strskip(currentIdx, (byte)' ', (byte)'\t', (byte)'\n', (byte)'\r', (byte)',')) < localBytesLength) {

				// ok, so the main algorithm is fairly simple. At this point, we've identified the start of an object enclosure, an array enclosure, or the start of a string
				// make an element for this and put it on the stack
				long nextCurrentIdx = currentIdx+1;

				if (localBytes [currentIdx] == (byte)'}' || localBytes [currentIdx] == (byte)']') {
					xmlElement = EndElement (elementStack, freeElementList, onEndElement);

				} else if (localBytes [currentIdx] == (byte)'{' || localBytes [currentIdx] == (byte)'[') {
					// we've found the start of a new object
					int parentIdx = -1;
					TBJSONElement parentElement = null;

					// this is not the root element, so we need an attribute to link it
					if (xmlAttribute.nameIdx != 0) {
						parentElement = xmlElement;
						parentIdx = xmlElement.values.Count;
						xmlAttribute.type = ValueType.Element;
						xmlAttribute.element = xmlElement;
						xmlElement.values.Add (xmlAttribute);
						xmlAttribute.Clear ();
					}

					
					if (freeElementList.Count > 0) {
						xmlElement = freeElementList.Pop ();
					} else {
						xmlElement = new TBJSONElement ();
						xmlElement.tbxml = this;
					}

					if (localBytes [currentIdx] == (byte)'{') {
						xmlElement.type = ElementType.Object;
					} else {
						xmlElement.type = ElementType.Array;
					}
						
					elementStack.Push (xmlElement);

					onStartElement (xmlElement, parentElement, parentIdx);
									
				} else if (xmlElement.type == ElementType.Object && localBytes [currentIdx] == (byte)'\"' || localBytes [currentIdx] == (byte)'\'') {

					// We've found the name portiong of a KVP
					if (xmlAttribute.nameIdx == 0) {
						// Set the attribute name index
						xmlAttribute.nameIdx = currentIdx + 1;

						// Find the name of the name string and null terminate it
						nextCurrentIdx = strstrNoEscaped (xmlAttribute.nameIdx, localBytes [currentIdx]);
						localBytes [nextCurrentIdx] = 0;

						// Find the ':'
						nextCurrentIdx = strstrNoEscaped (nextCurrentIdx + 1, (byte)':') + 1;

						// skip whitespace
						nextCurrentIdx = strskip(nextCurrentIdx, (byte)' ', (byte)'\t', (byte)'\n', (byte)'\r');

						// advance forward until we find the start of the next thing
						if (localBytes [nextCurrentIdx] == (byte)'\"' || localBytes [nextCurrentIdx] == (byte)'\'') {
							// our value is a string
							xmlAttribute.type = ValueType.String;
							xmlAttribute.valueIdx = nextCurrentIdx + 1;
							nextCurrentIdx = strstrNoEscaped (xmlAttribute.valueIdx, localBytes [nextCurrentIdx]);
							localBytes [nextCurrentIdx] = 0;
							nextCurrentIdx++;

							xmlElement.values.Add (xmlAttribute);
							xmlAttribute.Clear ();

						} else if (localBytes [nextCurrentIdx] == (byte)'{' || localBytes [nextCurrentIdx] == (byte)'[') {
							// our value is an array or an object; we will process it next time through the main loop
							//nextCurrentIdx = nextCurrentIdx - 1;

						} else if (localBytes [nextCurrentIdx] == (byte)'n' && localBytes [nextCurrentIdx + 1] == (byte)'u' && localBytes [nextCurrentIdx + 2] == (byte)'l' && localBytes [nextCurrentIdx + 3] == (byte)'l') {
							// our value is null; pick up at the end of it
							xmlAttribute.type = ValueType.Null;
							nextCurrentIdx += 4;

							xmlElement.values.Add (xmlAttribute);
							xmlAttribute.Clear ();
						} else {
							// our value is likely a number; capture it then advance to the next ',' or '}' or whitespace
							xmlAttribute.type = ValueType.Int;
							xmlAttribute.valueIdx = nextCurrentIdx;

							while (localBytes [nextCurrentIdx] != ' ' && localBytes [nextCurrentIdx] != '\t' && localBytes [nextCurrentIdx] != '\n' && localBytes [nextCurrentIdx] != '\r' && localBytes [nextCurrentIdx] != ',' && localBytes [nextCurrentIdx] != '}' && localBytes [nextCurrentIdx] != ']') {
								if (localBytes [nextCurrentIdx] == '.') {
									xmlAttribute.type = ValueType.Double;
								}
								nextCurrentIdx++;
							}

							xmlElement.values.Add (xmlAttribute);
							xmlAttribute.Clear ();


							if(localBytes [nextCurrentIdx] == (byte)']') {
								localBytes [nextCurrentIdx] = 0;
								xmlElement = EndElement (elementStack, freeElementList, onEndElement);
							}
							localBytes [nextCurrentIdx] = 0;
							nextCurrentIdx++;


						}
					} else {
						// We found the value portion of a KVP
						nextCurrentIdx = strstrNoEscaped (currentIdx, localBytes [currentIdx]);
						localBytes [nextCurrentIdx] = 0;

						// Find the ':'
						nextCurrentIdx = strstrNoEscaped (nextCurrentIdx, (byte)':');

						// create new attribute
						xmlAttribute.nameIdx = currentIdx;
					}
				} else {
					if (xmlElement.type == ElementType.Array) {
						// this could be an array element...
						nextCurrentIdx = strskip(currentIdx, (byte)' ', (byte)'\t', (byte)'\n', (byte)'\r');
							
						// advance forward until we find the start of the next thing
						if (localBytes [nextCurrentIdx] == (byte)'\"' || localBytes [nextCurrentIdx] == (byte)'\'') {
							// our value is a string
							xmlAttribute.type = ValueType.String;
							xmlAttribute.valueIdx = nextCurrentIdx + 1;
							nextCurrentIdx = strstrNoEscaped (xmlAttribute.valueIdx, localBytes [nextCurrentIdx]);
							localBytes [nextCurrentIdx] = 0;
							nextCurrentIdx++;

							xmlElement.values.Add (xmlAttribute);
							xmlAttribute.Clear ();

						} else if (localBytes [nextCurrentIdx] == (byte)'{' || localBytes [nextCurrentIdx] == (byte)'[') {
							// our value is an array or an object; we will process it next time through the main loop
							//nextCurrentIdx = nextCurrentIdx - 1;

						} else if (localBytes [nextCurrentIdx] == (byte)'n' && localBytes [nextCurrentIdx + 1] == (byte)'u' && localBytes [nextCurrentIdx + 2] == (byte)'l' && localBytes [nextCurrentIdx + 3] == (byte)'l') {
							// our value is null; pick up at the end of it
							xmlAttribute.type = ValueType.Null;
							nextCurrentIdx += 4;

							xmlElement.values.Add (xmlAttribute);
							xmlAttribute.Clear ();
						} else {
							// our value is likely a number; capture it then advance to the next ',' or '}' or whitespace
							xmlAttribute.type = ValueType.Int;
							xmlAttribute.valueIdx = nextCurrentIdx;

							while (localBytes [nextCurrentIdx] != ' ' && localBytes [nextCurrentIdx] != '\t' && localBytes [nextCurrentIdx] != '\n' && localBytes [nextCurrentIdx] != '\r' && localBytes [nextCurrentIdx] != ',' && localBytes [nextCurrentIdx] != '}' && localBytes [nextCurrentIdx] != ']') {
								if (localBytes [nextCurrentIdx] == '.') {
									xmlAttribute.type = ValueType.Double;
								}
								nextCurrentIdx++;
							}

							xmlElement.values.Add (xmlAttribute);
							xmlAttribute.Clear ();

							if(localBytes [nextCurrentIdx] == (byte)']') {
								localBytes [nextCurrentIdx] = 0;
								xmlElement = EndElement (elementStack, freeElementList, onEndElement);
							}
							localBytes [nextCurrentIdx] = 0;
							nextCurrentIdx++;

						}
					}
				}

				currentIdx = nextCurrentIdx;
			}

			while (elementStack.Count > 0) {
				xmlElement = EndElement (elementStack, freeElementList, onEndElement);
			}
		}

		private TBJSONElement EndElement(Stack<TBJSONElement> elementStack, Stack<TBJSONElement> freeElementList, Action<TBJSONElement,TBJSONElement,int> onEndElement) {
			if (elementStack.Count > 0) {
				TBJSONElement myElement = elementStack.Pop ();
				TBJSONElement parentElement = null;
				int parentIdx = -1;
				if (elementStack.Count > 0) {
					parentElement = elementStack.Peek ();
					parentIdx = parentElement.values.Count - 1;
				}
				onEndElement (myElement, parentElement, parentIdx);
				myElement.values.Clear ();
				freeElementList.Push (myElement);
				return parentElement;
			}
			return null;
		}

		#endregion

	}
}
