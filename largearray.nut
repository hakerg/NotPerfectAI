class LargeArray
{
	len = null;
	chunks = null;
	chunkCount = null;
	chunkLen = null;
}

function LargeArray::constructor(len)
{
	this.len = len;
	this.chunkCount = len;
	this.chunkLen = 1;
	while (chunkCount > 16384)
	{
		chunkCount = (chunkCount + 16383) / 16384;
		chunkLen *= 16384;
	}
	this.chunks = array(chunkCount);
}

function LargeArray::Get(index)
{
	if (chunkLen == 1)
	{
		return chunks[index];
	}
	else
	{
		local chunkIndex = index / chunkLen;
		if (chunks[chunkIndex] == null)
		{
			return null;
		}
		else
		{
			return chunks[chunkIndex].Get(index % chunkLen);
		}
	}
}

function LargeArray::Set(index, value)
{
	if (chunkLen == 1)
	{
		chunks[index] = value;
	}
	else
	{
		local chunkIndex = index / chunkLen;
		if (chunks[chunkIndex] == null)
		{
			chunks[chunkIndex] = LargeArray(chunkLen);
		}
		chunks[chunkIndex].Set(index % chunkLen, value);
	}
}