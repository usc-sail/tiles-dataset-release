import gzip
import os

class FileStreamer:
    def __init__(self):
        self._file_path = None
        self._infile = None
        self._file_offset = 0
        self.current_line = 0

    def __del__(self):
        if self._file_path is not None:
          self._infile.close()

    def LoadFile(self, file_path):
        self._file_path = file_path
        dummy, self._ext = os.path.splitext(file_path)
        if self._ext.endswith('gz'):
           self._infile = gzip.open(file_path, 'r')
        else:
           self._infile = open(file_path, 'r')
        self._file_offset = 0
        self.current_line = 0

    def GetNextLines(self, num_lines):
        data = None
        if num_lines > 0 and self._infile is not None:
            data = []
            #self._infile.seek(self._file_offset)
            line_count = 0
            for line in self._infile:
                self._file_offset += len(line)
                data_str = line.strip()
                if data_str:
                    data.append(data_str)
                line_count += 1
                self.current_line += 1
                if line_count >= num_lines:
                    break
        return data
