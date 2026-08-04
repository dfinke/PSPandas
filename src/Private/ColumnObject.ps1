if (-not ([System.Management.Automation.PSTypeName]'PSPandas.DataFrame').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Globalization;

namespace PSPandas
{
    public sealed class DataFrameColumn
    {
        private readonly object[] _values;

        public DataFrameColumn(string name, object[] values)
        {
            Name = name ?? string.Empty;
            _values = values ?? Array.Empty<object>();
        }

        public string Name { get; }

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
