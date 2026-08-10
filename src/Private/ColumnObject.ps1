<#
.SYNOPSIS
Defines the .NET types used by PSPandas DataFrames and workbook wrappers.

.DESCRIPTION
Compiles the DataFrame, DataFrameColumn, Workbook, WorksheetCollection, and
WorksheetInfo types once per PowerShell process. These types provide indexed
column operations, stable row storage, dynamic worksheet properties, and
tab-completable workbook access used by the public module commands.

.NOTES
This implementation file is loaded before the function-based module helpers.
#>

if (-not ([System.Management.Automation.PSTypeName]'PSPandas.DataFrame').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Globalization;

namespace PSPandas
{
    public sealed class DataFrameColumn : DynamicObject
    {
        private readonly object[] _values;

        public DataFrameColumn(string name, object[] values)
        {
            Name = name ?? string.Empty;
            _values = values ?? Array.Empty<object>();
        }

        public string Name { get; }

        public override bool TryGetIndex(GetIndexBinder binder, object[] indexes, out object result)
        {
            result = null;
            if (indexes == null || indexes.Length == 0)
            {
                throw new ArgumentException("Column indexing requires at least one integer index.");
            }

            var requested = new List<int>();
            if (indexes.Length == 1 && indexes[0] is Array)
            {
                var indexArray = (Array)indexes[0];
                for (var position = 0; position < indexArray.Length; position++)
                {
                    requested.Add(Convert.ToInt32(indexArray.GetValue(position), CultureInfo.InvariantCulture));
                }
            }
            else
            {
                for (var position = 0; position < indexes.Length; position++)
                {
                    if (indexes[position] is Array)
                    {
                        throw new ArgumentException("Column indexing accepts integer indexes or an integer range.");
                    }
                    requested.Add(Convert.ToInt32(indexes[position], CultureInfo.InvariantCulture));
                }
            }

            if (requested.Count == 1)
            {
                result = GetValue(requested[0]);
                return true;
            }

            var selected = new object[requested.Count];
            for (var position = 0; position < requested.Count; position++)
            {
                selected[position] = GetValue(requested[position]);
            }
            result = selected;
            return true;
        }

        private object GetValue(int requestedIndex)
        {
            var index = requestedIndex < 0 ? _values.Length + requestedIndex : requestedIndex;
            if (index < 0 || index >= _values.Length)
            {
                throw new IndexOutOfRangeException(
                    string.Format(
                        CultureInfo.InvariantCulture,
                        "Column '{0}' index {1} is outside the range 0..{2}.",
                        Name,
                        requestedIndex,
                        _values.Length - 1));
            }
            return _values[index];
        }

        public object[] Values
        {
            get
            {
                var copy = new object[_values.Length];
                Array.Copy(_values, copy, _values.Length);
                return copy;
            }
        }

        public int Count()
        {
            var count = 0;
            foreach (var value in _values)
            {
                if (value != null && value != DBNull.Value)
                {
                    count++;
                }
            }
            return count;
        }

        public double Sum()
        {
            var values = NumericValues();
            var total = 0d;
            foreach (var value in values)
            {
                total += value;
            }
            return total;
        }

        public object Average()
        {
            var values = NumericValues();
            if (values.Count == 0)
            {
                return null;
            }
            var total = 0d;
            foreach (var value in values)
            {
                total += value;
            }
            return total / values.Count;
        }

        public object Min()
        {
            var values = NumericValues();
            if (values.Count == 0)
            {
                return null;
            }
            var result = values[0];
            for (var index = 1; index < values.Count; index++)
            {
                if (values[index] < result)
                {
                    result = values[index];
                }
            }
            return result;
        }

        public object Max()
        {
            var values = NumericValues();
            if (values.Count == 0)
            {
                return null;
            }
            var result = values[0];
            for (var index = 1; index < values.Count; index++)
            {
                if (values[index] > result)
                {
                    result = values[index];
                }
            }
            return result;
        }

        private List<double> NumericValues()
        {
            var values = new List<double>();
            for (var index = 0; index < _values.Length; index++)
            {
                var value = _values[index];
                if (value == null || value == DBNull.Value)
                {
                    continue;
                }
                if (!IsNumericType(value.GetType()))
                {
                    throw new InvalidOperationException(
                        string.Format(
                            CultureInfo.InvariantCulture,
                            "Column '{0}' contains non-numeric value '{1}' of type '{2}' at index {3}. Numeric operations require numeric values.",
                            Name,
                            value,
                            value.GetType().FullName,
                            index));
                }
                values.Add(Convert.ToDouble(value, CultureInfo.InvariantCulture));
            }
            return values;
        }

        private static bool IsNumericType(Type type)
        {
            return type == typeof(byte)
                || type == typeof(sbyte)
                || type == typeof(short)
                || type == typeof(ushort)
                || type == typeof(int)
                || type == typeof(uint)
                || type == typeof(long)
                || type == typeof(ulong)
                || type == typeof(float)
                || type == typeof(double)
                || type == typeof(decimal);
        }
    }

    public sealed class DataFrame : DynamicObject
    {
        private readonly string[] _columns;
        private readonly object[] _rows;
        private readonly Dictionary<string, DataFrameColumn> _columnObjects;

        public DataFrame(string[] columns, object[] rows, DataFrameColumn[] columnObjects)
        {
            _columns = columns ?? Array.Empty<string>();
            _rows = rows ?? Array.Empty<object>();
            _columnObjects = new Dictionary<string, DataFrameColumn>(StringComparer.OrdinalIgnoreCase);
            if (columnObjects != null)
            {
                foreach (var column in columnObjects)
                {
                    if (column != null)
                    {
                        _columnObjects[column.Name] = column;
                    }
                }
            }
        }

        public string[] Columns { get { return _columns; } }

        public object[] Rows { get { return _rows; } }

        public int Count { get { return _rows.Length; } }

        public DataFrameColumn GetColumn(string name)
        {
            if (name == null)
            {
                throw new KeyNotFoundException("Column name cannot be null.");
            }
            DataFrameColumn column;
            if (_columnObjects.TryGetValue(name, out column))
            {
                return column;
            }
            throw new KeyNotFoundException(string.Format("Column '{0}' does not exist in the data frame.", name));
        }

        public override bool TryGetIndex(GetIndexBinder binder, object[] indexes, out object result)
        {
            result = null;
            if (indexes == null || indexes.Length != 1 || !(indexes[0] is string))
            {
                throw new ArgumentException("Data-frame indexing requires one string column name.");
            }
            result = GetColumn((string)indexes[0]);
            return true;
        }
    }
}
'@
}

if (-not ([System.Management.Automation.PSTypeName]'PSPandas.Workbook').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.Dynamic;

namespace PSPandas
{
    public sealed class WorksheetInfo
    {
        public WorksheetInfo(string name, object dataFrame, int count, string[] columns)
        {
            Name = name ?? string.Empty;
            DataFrame = dataFrame;
            Count = count;
            Columns = columns ?? Array.Empty<string>();
        }

        public string Name { get; }

        public object DataFrame { get; }

        public int Count { get; }

        public string[] Columns { get; }

        public override string ToString()
        {
            return Name;
        }
    }

    public sealed class WorksheetCollection : DynamicObject, IEnumerable
    {
        private readonly string[] _names;
        private readonly Dictionary<string, object> _frames;
        private readonly WorksheetInfo[] _items;

        public WorksheetCollection(string[] names, object[] frames)
        {
            _frames = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            var orderedNames = new List<string>();
            var items = new List<WorksheetInfo>();
            var sourceNames = names ?? Array.Empty<string>();
            var sourceFrames = frames ?? Array.Empty<object>();

            for (var index = 0; index < sourceNames.Length; index++)
            {
                var name = sourceNames[index] ?? string.Empty;
                if (name.Length == 0 || _frames.ContainsKey(name))
                {
                    continue;
                }

                var frame = index < sourceFrames.Length ? sourceFrames[index] : null;
                _frames.Add(name, frame);
                orderedNames.Add(name);
                var count = 0;
                var columns = Array.Empty<string>();
                if (frame != null)
                {
                    var frameType = frame.GetType();
                    var countProperty = frameType.GetProperty("Count");
                    var columnsProperty = frameType.GetProperty("Columns");
                    if (countProperty != null)
                    {
                        count = (int)countProperty.GetValue(frame, null);
                    }
                    if (columnsProperty != null)
                    {
                        columns = (string[])columnsProperty.GetValue(frame, null);
                    }
                }
                items.Add(new WorksheetInfo(name, frame, count, columns));
            }

            _names = orderedNames.ToArray();
            _items = items.ToArray();
        }

        public string[] Names
        {
            get
            {
                var copy = new string[_names.Length];
                Array.Copy(_names, copy, _names.Length);
                return copy;
            }
        }

        public int Count
        {
            get { return _names.Length; }
        }

        public WorksheetInfo[] Items
        {
            get
            {
                var copy = new WorksheetInfo[_items.Length];
                Array.Copy(_items, copy, _items.Length);
                return copy;
            }
        }

        public object this[string name]
        {
            get { return GetDataFrame(name); }
        }

        public object GetDataFrame(string name)
        {
            if (name == null)
            {
                throw new KeyNotFoundException("Worksheet name cannot be null.");
            }

            object frame;
            if (_frames.TryGetValue(name, out frame))
            {
                return frame;
            }

            throw new KeyNotFoundException(string.Format("Worksheet '{0}' does not exist in the workbook.", name));
        }

        public WorksheetInfo GetWorksheet(string name)
        {
            GetDataFrame(name);
            for (var index = 0; index < _items.Length; index++)
            {
                if (string.Equals(_items[index].Name, name, StringComparison.OrdinalIgnoreCase))
                {
                    return _items[index];
                }
            }

            throw new KeyNotFoundException(string.Format("Worksheet '{0}' does not exist in the workbook.", name));
        }

        public IEnumerator GetEnumerator()
        {
            return _items.GetEnumerator();
        }

        public override bool TryGetIndex(GetIndexBinder binder, object[] indexes, out object result)
        {
            result = null;
            if (indexes == null || indexes.Length != 1 || !(indexes[0] is string))
            {
                throw new ArgumentException("Workbook worksheet indexing requires one string worksheet name.");
            }

            result = GetDataFrame((string)indexes[0]);
            return true;
        }

        public override bool TryGetMember(GetMemberBinder binder, out object result)
        {
            result = GetDataFrame(binder.Name);
            return true;
        }

        public override IEnumerable<string> GetDynamicMemberNames()
        {
            return _names;
        }
    }

    public sealed class Workbook : DynamicObject
    {
        private readonly string[] _names;
        private readonly Dictionary<string, object> _frames;

        public Workbook(string path, string[] names, object[] frames)
        {
            Path = path ?? string.Empty;
            Worksheets = new WorksheetCollection(names, frames);
            _names = Worksheets.Names;
            _frames = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            var sourceFrames = frames ?? Array.Empty<object>();
            for (var index = 0; index < _names.Length; index++)
            {
                _frames[_names[index]] = index < sourceFrames.Length ? sourceFrames[index] : null;
            }
        }

        public string Path { get; }

        public WorksheetCollection Worksheets { get; }

        public string[] SheetNames
        {
            get { return Worksheets.Names; }
        }

        public object this[string name]
        {
            get { return Worksheets.GetDataFrame(name); }
        }

        public override bool TryGetIndex(GetIndexBinder binder, object[] indexes, out object result)
        {
            result = null;
            if (indexes == null || indexes.Length != 1 || !(indexes[0] is string))
            {
                throw new ArgumentException("Workbook indexing requires one string worksheet name.");
            }

            result = Worksheets.GetDataFrame((string)indexes[0]);
            return true;
        }

        public override bool TryGetMember(GetMemberBinder binder, out object result)
        {
            result = null;
            if (_frames.TryGetValue(binder.Name, out result))
            {
                return true;
            }

            throw new KeyNotFoundException(string.Format("Worksheet '{0}' does not exist in the workbook.", binder.Name));
        }

        public override IEnumerable<string> GetDynamicMemberNames()
        {
            return _names;
        }
    }
}
'@
}
